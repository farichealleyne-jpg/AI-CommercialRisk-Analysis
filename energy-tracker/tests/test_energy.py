"""Tests for the pieces that decide what a facility manager is shown."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from energy import analytics, db, seed  # noqa: E402
from energy.importer import export_csv, import_csv  # noqa: E402


def memory_db():
    return db.init(db.connect(":memory:"))


def reading(meter_id, period, consumption, cost=None, meter="M1", system="HVAC",
            utility="electricity", unit="kWh", unit_rate=0.15):
    return {"meter_id": meter_id, "period": period, "consumption": consumption, "cost": cost,
            "meter": meter, "system": system, "utility": utility, "unit": unit, "unit_rate": unit_rate}


class PeriodMathTests(unittest.TestCase):
    def test_shift_crosses_year_boundaries(self):
        self.assertEqual(analytics.shift_period("2026-01", -1), "2025-12")
        self.assertEqual(analytics.shift_period("2026-12", 1), "2027-01")
        self.assertEqual(analytics.shift_period("2026-06", -12), "2025-06")
        self.assertEqual(analytics.shift_period("2026-06", 18), "2027-12")

    def test_percent_change_without_baseline_is_none(self):
        self.assertIsNone(analytics.percent_change(100, 0))
        self.assertIsNone(analytics.percent_change(100, None))
        self.assertAlmostEqual(analytics.percent_change(120, 100), 0.2)


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.conn = memory_db()
        self.site = db.add_site(self.conn, "Test Plaza", 100_000)
        self.meter = db.add_meter(self.conn, self.site, "Chiller", "electricity", "HVAC", unit_rate=0.15)

    def test_reading_for_a_month_is_replaced_not_duplicated(self):
        db.upsert_reading(self.conn, self.meter, "2026-08", 1000, 150)
        db.upsert_reading(self.conn, self.meter, "2026-08", 1200, 180)
        rows = db.list_readings(self.conn, site_id=self.site)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["consumption"], 1200)

    def test_cost_falls_back_to_the_meter_rate(self):
        db.upsert_reading(self.conn, self.meter, "2026-08", 1000)
        self.assertAlmostEqual(db.list_readings(self.conn)[0]["cost"], 150.0)

    def test_bad_period_is_rejected(self):
        with self.assertRaises(ValueError):
            db.upsert_reading(self.conn, self.meter, "August 2026", 10)

    def test_negative_consumption_is_rejected(self):
        with self.assertRaises(ValueError):
            db.upsert_reading(self.conn, self.meter, "2026-08", -5)


class SeriesTests(unittest.TestCase):
    def test_missing_months_appear_as_zero(self):
        rows = [reading(1, "2026-07", 100), reading(1, "2026-09", 300)]
        series = analytics.monthly_series(rows, months=3, end_period="2026-09")
        self.assertEqual([r["period"] for r in series], ["2026-07", "2026-08", "2026-09"])
        self.assertEqual([r["consumption"] for r in series], [100, 0, 300])

    def test_breakdown_shares_sum_to_one(self):
        rows = [reading(1, "2026-09", 60, system="HVAC"),
                reading(2, "2026-09", 40, system="Lighting")]
        shares = analytics.breakdown(rows, period="2026-09")
        self.assertAlmostEqual(sum(r["share"] for r in shares), 1.0)
        self.assertEqual(shares[0]["system"], "HVAC")

    def test_kpis_compare_against_the_prior_month(self):
        rows = [reading(1, "2026-08", 1000, 150), reading(1, "2026-09", 1100, 170)]
        k = analytics.kpis(rows, period="2026-09")
        self.assertAlmostEqual(k["consumption_change"], 0.1)
        self.assertAlmostEqual(k["cost_change"], (170 - 150) / 150)


class ReportingPeriodTests(unittest.TestCase):
    def full_year(self, meters=8, months=9):
        return [reading(m, "2026-%02d" % mo, 1000, meter="M%d" % m)
                for mo in range(1, months + 1) for m in range(1, meters + 1)]

    def test_one_early_bill_does_not_become_the_headline_month(self):
        rows = self.full_year() + [reading(1, "2026-10", 900, meter="M1")]
        self.assertEqual(analytics.latest_complete_period(rows), "2026-09")

    def test_the_month_becomes_current_once_most_meters_report(self):
        rows = self.full_year() + [reading(m, "2026-10", 900, meter="M%d" % m) for m in range(1, 8)]
        self.assertEqual(analytics.latest_complete_period(rows), "2026-10")

    def test_a_brand_new_site_uses_what_it_has(self):
        self.assertEqual(analytics.latest_complete_period([reading(1, "2026-10", 900)]), "2026-10")

    def test_no_readings_has_no_period(self):
        self.assertIsNone(analytics.latest_complete_period([]))


class AnomalyTests(unittest.TestCase):
    def steady_history(self, value=1000, months=6, end="2026-09"):
        return [reading(1, analytics.shift_period(end, -i), value) for i in range(1, months + 1)]

    def test_a_spike_above_baseline_is_flagged_high(self):
        rows = self.steady_history() + [reading(1, "2026-09", 1400)]
        alerts = analytics.detect_anomalies(rows, period="2026-09")
        self.assertEqual(len(alerts), 1)
        self.assertEqual(alerts[0]["severity"], "high")
        self.assertEqual(alerts[0]["kind"], "spike")
        self.assertAlmostEqual(alerts[0]["change"], 0.4)

    def test_normal_variation_is_not_flagged(self):
        rows = self.steady_history() + [reading(1, "2026-09", 1050)]
        self.assertEqual(analytics.detect_anomalies(rows, period="2026-09"), [])

    def test_a_collapse_reads_as_a_meter_to_check(self):
        rows = self.steady_history() + [reading(1, "2026-09", 300)]
        alerts = analytics.detect_anomalies(rows, period="2026-09")
        self.assertEqual(alerts[0]["kind"], "dropout")

    def test_a_meter_without_history_is_left_alone(self):
        rows = [reading(1, "2026-08", 1000), reading(1, "2026-09", 9000)]
        self.assertEqual(analytics.detect_anomalies(rows, period="2026-09"), [])

    def test_each_meter_is_judged_against_itself(self):
        # A small meter spiking matters; a large steady meter does not drown it out.
        rows = []
        for i in range(1, 7):
            period = analytics.shift_period("2026-09", -i)
            rows.append(reading(1, period, 50_000, meter="Chiller"))
            rows.append(reading(2, period, 500, meter="Garage Lights"))
        rows.append(reading(1, "2026-09", 50_500, meter="Chiller"))
        rows.append(reading(2, "2026-09", 700, meter="Garage Lights"))
        alerts = analytics.detect_anomalies(rows, period="2026-09")
        self.assertEqual([a["meter"] for a in alerts], ["Garage Lights"])

    def test_excess_cost_uses_the_billed_rate_when_present(self):
        rows = [reading(1, analytics.shift_period("2026-09", -i), 1000, cost=200) for i in range(1, 7)]
        rows.append(reading(1, "2026-09", 1500, cost=300))
        alert = analytics.detect_anomalies(rows, period="2026-09")[0]
        self.assertAlmostEqual(alert["excess_consumption"], 500)
        self.assertAlmostEqual(alert["excess_cost"], 100.0)  # 500 units at the billed $0.20


class ForecastTests(unittest.TestCase):
    def test_seasonal_shape_is_reused_from_last_year(self):
        rows = []
        for i in range(0, 24):
            period = analytics.shift_period("2026-09", -i)
            month = int(period.split("-")[1])
            rows.append(reading(1, period, 1000 + (500 if month in (6, 7, 8) else 0), cost=150))
        projection = analytics.forecast(rows, months=3, end_period="2026-09")
        self.assertEqual([p["period"] for p in projection], ["2026-10", "2026-11", "2026-12"])
        self.assertEqual(projection[0]["label"], "Oct 2026")
        # October is off-season: the projection should sit near the 1000 base, not the summer peak.
        self.assertLess(projection[0]["consumption"], 1200)

    def test_falls_back_to_a_trailing_average_without_a_year_of_data(self):
        rows = [reading(1, "2026-07", 900), reading(1, "2026-08", 1000), reading(1, "2026-09", 1100)]
        projection = analytics.forecast(rows, months=1, end_period="2026-09")
        self.assertAlmostEqual(projection[0]["consumption"], 1000.0)
        self.assertIn("last three months", projection[0]["basis"])

    def test_cost_is_projected_from_cost_not_from_mixed_units(self):
        # Gallons of water dwarf kWh; a rate blended across both would wreck the
        # cost projection, so each metric is projected from its own history.
        rows = []
        for i in range(0, 24):
            period = analytics.shift_period("2026-09", -i)
            rows.append(reading(1, period, 1000, cost=150, utility="electricity"))
            rows.append(reading(2, period, 300_000, cost=360, meter="Water", utility="water", unit="gal"))
        projection = analytics.forecast(rows, months=1, end_period="2026-09")[0]
        self.assertAlmostEqual(projection["cost"], 510, delta=1)

    def test_budget_variance_projects_the_year_end(self):
        rows = [reading(1, "2026-%02d" % m, 1000, cost=150) for m in range(1, 7)]
        variance = analytics.budget_variance(rows, annual_budget=1800, end_period="2026-06")
        self.assertEqual(variance["spent_to_date"], 900)
        self.assertGreater(variance["projected_year_end"], 900)


class CarbonTests(unittest.TestCase):
    def test_each_utility_uses_its_own_factor(self):
        rows = [reading(1, "2026-09", 1000, utility="electricity"),
                reading(2, "2026-09", 100, utility="gas", unit="therms")]
        expected = 1000 * db.UTILITIES["electricity"]["co2e_per_unit"] + \
                   100 * db.UTILITIES["gas"]["co2e_per_unit"]
        self.assertAlmostEqual(analytics.carbon(rows, period="2026-09"), expected)

    def test_intensity_needs_a_floor_area(self):
        rows = [reading(1, "2026-09", 100_000)]
        self.assertIsNone(analytics.energy_use_intensity(rows, None, period="2026-09"))
        self.assertAlmostEqual(analytics.energy_use_intensity(rows, 50_000, period="2026-09"), 2.0)


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.conn = memory_db()
        self.site = db.add_site(self.conn, "Import Site")

    def test_import_creates_meters_and_readings(self):
        csv_text = (
            "period,meter,utility,system,consumption,cost,unit_rate\n"
            "2026-08,Chiller,electricity,HVAC,48000,7104,0.148\n"
            "2026-09,Chiller,electricity,HVAC,51000,7548,0.148\n"
            "2026-09,Boiler,gas,Heating,2400,3168,1.32\n"
        )
        result = import_csv(self.conn, csv_text, self.site)
        self.assertEqual(result["imported"], 3)
        self.assertEqual(result["created_meters"], 2)
        self.assertEqual(result["errors"], [])

    def test_bad_rows_are_skipped_and_reported(self):
        csv_text = (
            "period,meter,consumption\n"
            "2026-09,Chiller,48000\n"
            "not-a-month,Chiller,1000\n"
            "2026-09,Chiller,not-a-number\n"
        )
        result = import_csv(self.conn, csv_text, self.site)
        self.assertEqual(result["imported"], 1)
        self.assertEqual(len(result["errors"]), 2)

    def test_missing_columns_are_named(self):
        result = import_csv(self.conn, "period,meter\n2026-09,Chiller\n", self.site)
        self.assertEqual(result["imported"], 0)
        self.assertIn("consumption", result["errors"][0])

    def test_export_round_trips_into_a_fresh_database(self):
        import_csv(self.conn, "period,meter,consumption,cost\n2026-09,Chiller,48000,7104\n", self.site)
        exported = export_csv(db.list_readings(self.conn))
        other = memory_db()
        site = db.add_site(other, "Copy")
        result = import_csv(other, exported, site)
        self.assertEqual(result["imported"], 1)
        self.assertAlmostEqual(db.list_readings(other)[0]["cost"], 7104.0)


class DashboardTests(unittest.TestCase):
    def setUp(self):
        self.conn = memory_db()
        self.site = seed.build(self.conn, "2026-09")

    def test_seeded_site_produces_a_complete_dashboard(self):
        data = analytics.dashboard(self.conn, site_id=self.site, annual_budget=400_000)
        self.assertFalse(data["empty"])
        self.assertEqual(data["period"], "2026-09")
        self.assertEqual(len(data["series"]), 12)
        self.assertEqual(len(data["forecast"]), 3)
        # The projection covers the same meters the headline chart shows, so it
        # cannot come back an order of magnitude off by folding in water gallons.
        latest_use = data["series"][-1]["consumption"]
        self.assertLess(data["forecast"][0]["consumption"], latest_use * 2)
        self.assertGreater(data["kpis"]["cost"], 0)
        self.assertGreater(data["kpis"]["co2e_kg"], 0)
        self.assertIsNotNone(data["kpis"]["eui"])
        self.assertAlmostEqual(sum(r["share"] for r in data["by_system"]), 1.0)
        self.assertIsNotNone(data["budget"])

    def test_the_seeded_fault_surfaces_as_an_alert(self):
        data = analytics.dashboard(self.conn, site_id=self.site)
        self.assertIn("HVAC - Chiller Plant", [a["meter"] for a in data["alerts"]])

    def test_a_partial_new_month_is_held_back_and_flagged(self):
        meters = db.list_meters(self.conn, self.site)
        db.upsert_reading(self.conn, meters[0]["id"], "2026-10", 500)
        data = analytics.dashboard(self.conn, site_id=self.site)
        self.assertEqual(data["period"], "2026-09")
        self.assertEqual(data["pending_period"], "Oct 2026")
        # The headline must reflect the full month, not one meter's early bill.
        self.assertGreater(data["kpis"]["consumption"], 10_000)

    def test_an_empty_database_renders_rather_than_crashing(self):
        blank = memory_db()
        data = analytics.dashboard(blank)
        self.assertTrue(data["empty"])
        self.assertIsNone(data["kpis"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
