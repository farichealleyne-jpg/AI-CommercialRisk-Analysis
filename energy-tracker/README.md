# Energy & Utility Tracker

A small consumption tracker for commercial sites: record or import utility
bills, see where the energy goes, catch meters that break from their own
pattern, and project the next quarter's spend.

It is deliberately boring technology - Python standard library and SQLite on
the server, plain HTML/CSS/JS on the page. No package install, no build step,
no CDN. That matters for this use case: building-systems networks are often
isolated, and a tool that needs the internet to draw a chart does not get
deployed there.

```bash
python3 server.py --seed     # first run: a demo site with two years of bills
python3 server.py            # afterwards
# http://localhost:8765
```

Tests: `python3 -m unittest discover -s tests`

## What it shows

| Panel | Question it answers |
| --- | --- |
| KPI tiles | What did we use and spend this month, against last month and last year? |
| Energy use over time | Is the trend going the right way, and what is coming? |
| Energy use by system | Which systems are actually driving the bill? |
| Exceptions worth a look | Which meters have broken from their own normal? |
| Biggest movers | Where did this month's change in dollars come from? |
| Projection & budget | What does the rest of the year look like? |

The tiles for carbon and energy use intensity (kWh/ft²) exist so the same
readings answer sustainability and benchmarking questions without a second
system.

## How it works

```
web/index.html + app.js   the dashboard; SVG charts drawn by hand
        |  fetch /api/...
server.py                 routing, static files, JSON
        |
energy/analytics.py       series, breakdowns, anomalies, forecast, carbon
energy/importer.py        CSV in and out
energy/db.py              SQLite schema and queries
```

**Data model.** A `site` has `meters`; a meter has one `reading` per billing
month. One reading per meter per month is the whole model - re-entering a month
overwrites it, which is what happens in practice when a utility reissues a bill.
Monthly granularity matches how the data actually arrives. Interval data (15-minute
pulses from a BMS) would want a separate time-series table; the analytics layer
would not change much, since it already works off a list of readings.

**Cost.** A reading stores the billed amount when you have it. When you do not,
cost falls back to the meter's `unit_rate`, so a site can get value from meter
reads before the bills are reconciled.

**Anomaly detection.** Each meter is compared against the median of its own
previous six months, not against other meters or a global threshold. A 500 kWh
garage lighting circuit stuck on overnight is a large fault and a small number;
judging every meter against itself is what makes it visible. Above +25% is high,
+12% is worth noting, and below -40% is reported as a meter to check rather than
a saving - a dead meter otherwise looks like your best month ever.

**Forecast.** Seasonal-naive with a trend factor: next June starts from last
June, scaled by how the last three months compare with the same three months a
year earlier. Under a year of history, it falls back to a trailing three-month
average and says so. Consumption and cost are projected separately, so a site
mixing kWh, therms and gallons never has one blended rate applied across all three.

**Reporting month.** Bills arrive at different times, so the dashboard anchors on
the newest month that most meters have reported, and notes the partial month
still coming in. Without that, one early bill makes a whole site look like it
shut down.

## Getting data in

Three ways, in the order most sites adopt them:

1. **Type it in** - the form on the dashboard, one meter-month at a time.
2. **Import CSV** - paste or upload a bill history. Columns: `period, meter,
   utility, system, consumption, cost, unit_rate`. Unknown meters are created on
   import, bad rows are skipped and reported by line number rather than failing
   the file. See `sample_data/readings.csv`.
3. **POST to the API** - for a nightly job pulling from a utility portal, a
   BMS export, or a green-button feed.

```
GET    /api/dashboard?site=1&months=12&budget=300000
GET    /api/readings?site=1&utility=electricity&limit=50
GET    /api/meters?site=1
GET    /api/export.csv?site=1
POST   /api/sites        {"name": "...", "floor_area_sqft": 128000}
POST   /api/meters       {"site_id": 1, "name": "...", "utility": "electricity",
                          "system": "HVAC", "unit_rate": 0.148}
POST   /api/readings     {"meter_id": 1, "period": "2026-09",
                          "consumption": 48000, "cost": 7104}
POST   /api/import       (CSV body)
DELETE /api/readings/{id}
```

## Scope and limits

Honest about what this is and is not:

- **Monthly, not real-time.** It tracks bills and meter reads. Live submetering
  needs an interval table and a poller.
- **Single-user, no auth.** It binds to localhost by default. Exposing it beyond
  a trusted network means putting it behind the platform's auth first.
- **SQLite.** Fine for hundreds of sites and years of monthly readings. Interval
  data would want Postgres.
- **Emission factors are US grid averages** (`energy/db.py`, `UTILITIES`).
  Replace them with your region's factors before reporting the carbon number
  externally.
- **The forecast is a projection, not a commitment.** It assumes next year looks
  like last year, adjusted for trend. A tenant moving in or out breaks that
  assumption, and the tracker cannot know about it.

## Fitting into PolicySquare

This runs standalone on purpose - it is useful on day one without touching the
Java backend or the Flutter app. If it earns a place in the platform, the path is:

- **Backend.** `Site` maps to the existing `Property`; `Meter` and `Reading`
  become two more JPA entities with a `UtilityReadingService` holding the logic
  in `analytics.py`. The endpoints above already mirror the existing controller
  shape.
- **App.** A `UtilityDashboardScreen` alongside `property_manager_dashboard_screen.dart`,
  fed by a `utility_repository.dart` - the same pattern the property budget
  feature uses.
- **Underwriting.** This is the part worth doing. A building whose consumption
  jumps 30% without explanation is a building with a deferred-maintenance
  problem, and that is a risk signal. The anomaly output already carries meter,
  system, magnitude and dollar impact, which is enough to feed a risk score or
  raise an action item in the inspection tracker.
