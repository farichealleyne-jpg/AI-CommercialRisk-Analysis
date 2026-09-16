"""Turning meter readings into the numbers a facility manager acts on.

A dashboard full of readings saves nothing on its own. Everything here exists
to answer one of four questions: what did we use, what did it cost, what
changed unexpectedly, and what will next quarter look like.
"""

from datetime import date

from .db import UTILITIES, list_meters, list_readings, resolved_cost

# A jump this far above a meter's own baseline is worth someone looking at.
ANOMALY_HIGH = 0.25
ANOMALY_MEDIUM = 0.12
# A collapse this far below baseline usually means a failed meter, not a saving.
DROPOUT_THRESHOLD = -0.40
# Months of history used as a meter's baseline.
BASELINE_MONTHS = 6


def shift_period(period, months):
    """Move a YYYY-MM string by a signed number of months."""
    year, month = (int(p) for p in period.split("-"))
    total = year * 12 + (month - 1) + months
    return "%04d-%02d" % (total // 12, total % 12 + 1)


def period_label(period):
    year, month = (int(p) for p in period.split("-"))
    return "%s %d" % (date(year, month, 1).strftime("%b"), year)


def short_label(period):
    """Axis form: the month alone, with the year shown when it turns over."""
    year, month = (int(p) for p in period.split("-"))
    name = date(year, month, 1).strftime("%b")
    return "%s '%s" % (name, str(year)[2:]) if month == 1 else name


def percent_change(current, previous):
    """Signed fractional change, or None when there is no baseline to compare to."""
    if previous is None or previous == 0:
        return None
    return (current - previous) / previous


def monthly_series(readings, months=12, end_period=None):
    """Consumption and cost per month, gaps filled with zeros so charts stay honest."""
    if not readings:
        return []
    end = end_period or max(r["period"] for r in readings)
    wanted = [shift_period(end, -i) for i in range(months - 1, -1, -1)]
    buckets = {p: {"period": p, "label": period_label(p), "short_label": short_label(p),
                   "consumption": 0.0, "cost": 0.0} for p in wanted}
    for r in readings:
        bucket = buckets.get(r["period"])
        if bucket:
            bucket["consumption"] += float(r["consumption"])
            bucket["cost"] += resolved_cost(r)
    return [buckets[p] for p in wanted]


def breakdown(readings, key="system", period=None):
    """Share of consumption by system (or utility) for one month."""
    scope = [r for r in readings if period is None or r["period"] == period]
    totals = {}
    for r in scope:
        totals[r[key]] = totals.get(r[key], 0.0) + float(r["consumption"])
    grand = sum(totals.values())
    rows = [
        {
            key: name,
            "consumption": value,
            "share": (value / grand) if grand else 0.0,
        }
        for name, value in totals.items()
    ]
    return sorted(rows, key=lambda row: row["consumption"], reverse=True)


def kpis(readings, period=None):
    """Headline tiles: usage, spend and intensity for a month against the one before."""
    if not readings:
        return None
    current = period or max(r["period"] for r in readings)
    previous = shift_period(current, -1)
    year_ago = shift_period(current, -12)

    def totals(target):
        rows = [r for r in readings if r["period"] == target]
        return {
            "consumption": sum(float(r["consumption"]) for r in rows),
            "cost": sum(resolved_cost(r) for r in rows),
            "count": len(rows),
        }

    now, prior, last_year = totals(current), totals(previous), totals(year_ago)
    return {
        "period": current,
        "label": period_label(current),
        "consumption": now["consumption"],
        "cost": now["cost"],
        "consumption_change": percent_change(now["consumption"], prior["consumption"] or None),
        "cost_change": percent_change(now["cost"], prior["cost"] or None),
        "consumption_change_yoy": percent_change(now["consumption"], last_year["consumption"] or None),
        "reading_count": now["count"],
    }


def carbon(readings, period=None):
    """Estimated CO2e in kg for a month, using per-utility emission factors."""
    scope = [r for r in readings if period is None or r["period"] == period]
    total = 0.0
    for r in scope:
        factor = UTILITIES.get(r["utility"], {}).get("co2e_per_unit", 0.0)
        total += float(r["consumption"]) * factor
    return total


def energy_use_intensity(readings, floor_area_sqft, period=None):
    """kWh per square foot for a month - the number that compares two buildings."""
    if not floor_area_sqft:
        return None
    scope = [r for r in readings if r["utility"] == "electricity" and (period is None or r["period"] == period)]
    if not scope:
        return None
    return sum(float(r["consumption"]) for r in scope) / float(floor_area_sqft)


def latest_complete_period(readings, coverage=0.75):
    """The newest month most meters have actually reported.

    Bills arrive at different times. Anchoring the dashboard on the newest month
    with any reading at all would make one early meter look like a site-wide
    collapse, so a month is only the headline once enough meters are in.
    """
    if not readings:
        return None
    meters_by_period = {}
    for r in readings:
        meters_by_period.setdefault(r["period"], set()).add(r["meter_id"])
    periods = sorted(meters_by_period, reverse=True)
    # A typical month's meter count, taken over the last year so that meters
    # added or retired along the way do not skew what "fully reported" means.
    expected = _median([len(meters_by_period[p]) for p in periods[:12]]) or 0
    if not expected:
        return periods[0]
    for period in periods:
        if len(meters_by_period[period]) >= expected * coverage:
            return period
    return periods[0]


def _median(values):
    ordered = sorted(values)
    n = len(ordered)
    if not n:
        return None
    mid = n // 2
    if n % 2:
        return ordered[mid]
    return (ordered[mid - 1] + ordered[mid]) / 2.0


def detect_anomalies(readings, period=None, baseline_months=BASELINE_MONTHS):
    """Flag meters whose latest month departs from their own recent history.

    Each meter is compared against its own median, so a large chiller and a
    lighting panel are both judged on their normal behaviour rather than
    against each other.
    """
    if not readings:
        return []
    current = period or max(r["period"] for r in readings)
    window = [shift_period(current, -i) for i in range(1, baseline_months + 1)]

    by_meter = {}
    for r in readings:
        by_meter.setdefault(r["meter_id"], []).append(r)

    alerts = []
    for meter_id, rows in by_meter.items():
        latest = next((r for r in rows if r["period"] == current), None)
        if latest is None:
            continue
        history = [float(r["consumption"]) for r in rows if r["period"] in window]
        if len(history) < 2:
            continue
        baseline = _median(history)
        change = percent_change(float(latest["consumption"]), baseline)
        if change is None:
            continue
        if change >= ANOMALY_HIGH:
            severity, kind = "high", "spike"
        elif change >= ANOMALY_MEDIUM:
            severity, kind = "medium", "spike"
        elif change <= DROPOUT_THRESHOLD:
            severity, kind = "medium", "dropout"
        else:
            continue
        excess = float(latest["consumption"]) - baseline
        unit_cost = _unit_cost(latest)
        alerts.append({
            "meter_id": meter_id,
            "meter": latest["meter"],
            "system": latest["system"],
            "utility": latest["utility"],
            "unit": latest["unit"],
            "period": current,
            "kind": kind,
            "severity": severity,
            "consumption": float(latest["consumption"]),
            "baseline": baseline,
            "change": change,
            "excess_consumption": excess,
            "excess_cost": excess * unit_cost,
            "message": _alert_message(latest, kind, change),
        })
    order = {"high": 0, "medium": 1}
    return sorted(alerts, key=lambda a: (order[a["severity"]], -abs(a["change"])))


def _unit_cost(reading):
    """What one more unit on this meter costs, from the bill where we have it."""
    usage = float(reading["consumption"])
    if reading.get("cost") is not None and usage:
        return resolved_cost(reading) / usage
    return float(reading.get("unit_rate") or 0.0)


def _alert_message(reading, kind, change):
    pct = abs(change) * 100
    if kind == "spike":
        return "%s is running %.0f%% above its 6-month normal - check schedules, setpoints and faults." % (
            reading["meter"], pct)
    return "%s reported %.0f%% below normal - verify the meter is reporting before booking the saving." % (
        reading["meter"], pct)


def forecast(readings, months=3, end_period=None):
    """Project the next few months from last year's shape and this year's trend.

    Seasonal-naive with a trend factor: a June forecast starts from last June,
    scaled by how the last three months compare with the same three months a
    year earlier. Without a year of history it falls back to a trailing mean.
    Consumption and cost are each projected from their own history, so a site
    mixing kWh, therms and gallons never has one rate applied across all three.
    """
    if not readings:
        return []
    end = end_period or max(r["period"] for r in readings)
    series = {row["period"]: row for row in monthly_series(readings, months=36, end_period=end)}

    out = []
    for step in range(1, months + 1):
        target = shift_period(end, step)
        use, basis = _project(series, end, target, "consumption")
        cost, _ = _project(series, end, target, "cost")
        out.append({
            "period": target,
            "label": period_label(target),
            "short_label": short_label(target),
            "consumption": use,
            "cost": cost,
            "basis": basis,
        })
    return out


def _project(series, end, target, metric):
    """One metric, one future month: seasonal-naive with trend, else trailing mean."""
    recent = [series[shift_period(end, -i)] for i in range(0, 3) if shift_period(end, -i) in series]
    recent_total = sum(r[metric] for r in recent)
    prior_year = [series.get(shift_period(end, -i - 12)) for i in range(0, 3)]
    prior_total = sum(r[metric] for r in prior_year if r)
    trend = (recent_total / prior_total) if prior_total else None

    seasonal = series.get(shift_period(target, -12))
    if seasonal and seasonal[metric] > 0 and trend:
        return seasonal[metric] * trend, "same month last year, adjusted for this year's trend"
    observed = [r[metric] for r in recent if r[metric] > 0]
    mean = sum(observed) / len(observed) if observed else 0.0
    return mean, "average of the last three months"


def budget_variance(readings, annual_budget, end_period=None):
    """Spend so far this calendar year against budget, plus the projected finish."""
    if not annual_budget:
        return None
    end = end_period or max(r["period"] for r in readings)
    year = end.split("-")[0]
    spent = sum(resolved_cost(r) for r in readings if r["period"].startswith(year))
    elapsed = int(end.split("-")[1])
    remaining = 12 - elapsed
    projection = forecast(readings, months=remaining, end_period=end) if remaining else []
    projected_year = spent + sum(f["cost"] for f in projection)
    return {
        "year": year,
        "budget": float(annual_budget),
        "spent_to_date": spent,
        "months_elapsed": elapsed,
        "projected_year_end": projected_year,
        "variance": projected_year - float(annual_budget),
        "variance_pct": percent_change(projected_year, float(annual_budget)),
    }


def top_movers(readings, period=None, limit=5):
    """Meters that moved the most month over month, in cost terms."""
    if not readings:
        return []
    current = period or max(r["period"] for r in readings)
    previous = shift_period(current, -1)
    now = {r["meter_id"]: r for r in readings if r["period"] == current}
    before = {r["meter_id"]: r for r in readings if r["period"] == previous}
    movers = []
    for meter_id, r in now.items():
        prior = before.get(meter_id)
        if not prior:
            continue
        delta_cost = resolved_cost(r) - resolved_cost(prior)
        movers.append({
            "meter": r["meter"],
            "system": r["system"],
            "utility": r["utility"],
            "unit": r["unit"],
            "delta_consumption": float(r["consumption"]) - float(prior["consumption"]),
            "delta_cost": delta_cost,
            "change": percent_change(float(r["consumption"]), float(prior["consumption"])),
        })
    movers.sort(key=lambda m: abs(m["delta_cost"]), reverse=True)
    return movers[:limit]


def dashboard(conn, site_id=None, months=12, annual_budget=None):
    """Everything the dashboard screen needs, in one pass over the readings."""
    readings = list_readings(conn, site_id=site_id)
    meters = list_meters(conn, site_id=site_id)
    if not readings:
        return {
            "empty": True,
            "meters": meters,
            "kpis": None,
            "series": [],
            "by_system": [],
            "by_utility": [],
            "alerts": [],
            "forecast": [],
            "movers": [],
        }

    current = latest_complete_period(readings)
    newest = max(r["period"] for r in readings)
    electricity = [r for r in readings if r["utility"] == "electricity"]
    site = None
    if site_id:
        row = conn.execute("SELECT * FROM sites WHERE id = ?", (site_id,)).fetchone()
        site = dict(row) if row else None

    headline = kpis(electricity or readings, period=current)
    headline["unit"] = "kWh" if electricity else readings[0]["unit"]
    headline["co2e_kg"] = carbon(readings, period=current)
    headline["eui"] = energy_use_intensity(readings, site["floor_area_sqft"] if site else None, period=current)

    return {
        "empty": False,
        "site": site,
        "period": current,
        "pending_period": period_label(newest) if newest != current else None,
        "kpis": headline,
        "series": monthly_series(electricity or readings, months=months, end_period=current),
        "cost_series": monthly_series(readings, months=months, end_period=current),
        "by_system": breakdown(electricity or readings, key="system", period=current),
        "by_utility": breakdown(readings, key="utility", period=current),
        "alerts": detect_anomalies(readings, period=current),
        "forecast": forecast(electricity or readings, months=3, end_period=current),
        "movers": top_movers(readings, period=current),
        "budget": budget_variance(readings, annual_budget, end_period=current) if annual_budget else None,
        "meters": meters,
    }
