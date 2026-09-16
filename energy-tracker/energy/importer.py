"""CSV import - the path most sites will actually use to get data in.

Expected columns: period, meter, utility, system, consumption, cost, unit_rate.
Meters are created on first sight so a year of history loads in one file.
"""

import csv
import io

from . import db

REQUIRED = {"period", "meter", "consumption"}


def import_csv(conn, text, site_id, default_utility="electricity", default_system="Other"):
    """Load readings from CSV text. Returns a summary, never raises on one bad row."""
    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames is None:
        return {"imported": 0, "created_meters": 0, "errors": ["file is empty"]}
    headers = {(h or "").strip().lower() for h in reader.fieldnames}
    missing = REQUIRED - headers
    if missing:
        return {"imported": 0, "created_meters": 0,
                "errors": ["missing required column(s): %s" % ", ".join(sorted(missing))]}

    existing = {m["name"]: m for m in db.list_meters(conn, site_id)}
    imported, created, errors = 0, 0, []

    for line_no, raw in enumerate(reader, start=2):
        row = {(k or "").strip().lower(): (v or "").strip() for k, v in raw.items()}
        try:
            period = db.validate_period(row["period"])
            name = row["meter"]
            if not name:
                raise ValueError("meter name is blank")
            consumption = float(row["consumption"])
            cost = float(row["cost"]) if row.get("cost") else None
            rate = float(row["unit_rate"]) if row.get("unit_rate") else None

            meter = existing.get(name)
            if meter is None:
                utility = row.get("utility") or default_utility
                if utility not in db.UTILITIES:
                    raise ValueError("unknown utility %r" % utility)
                meter_id = db.add_meter(conn, site_id, name, utility,
                                        row.get("system") or default_system,
                                        unit_rate=rate or 0.0)
                existing[name] = {"id": meter_id, "name": name}
                meter = existing[name]
                created += 1
            db.upsert_reading(conn, meter["id"], period, consumption, cost, source="csv")
            imported += 1
        except (ValueError, KeyError, TypeError) as exc:
            errors.append("line %d: %s" % (line_no, exc))

    return {"imported": imported, "created_meters": created, "errors": errors}


def export_csv(readings):
    """Readings back out as CSV, for finance or a spreadsheet model."""
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["period", "meter", "utility", "system", "consumption", "unit", "cost"])
    for r in sorted(readings, key=lambda x: (x["period"], x["meter"])):
        writer.writerow([r["period"], r["meter"], r["utility"], r["system"],
                         round(float(r["consumption"]), 2), r["unit"], round(r["cost"], 2)])
    return out.getvalue()
