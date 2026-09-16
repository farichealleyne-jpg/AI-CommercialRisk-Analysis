"""Demo data: two years of plausible readings for a mixed-use commercial site.

Deterministic on purpose - the same numbers appear on every machine, so the
dashboard and the tests describe the same building.
"""

import math
import random

from . import db
from .analytics import shift_period

SITE = {"name": "Graywood Commercial Plaza", "floor_area_sqft": 128_000}

METERS = [
    # name,                 utility,       system,          $/unit, base monthly use, seasonal swing
    ("HVAC - Chiller Plant", "electricity", "HVAC",          0.148, 48_000, 0.55),
    ("HVAC - Air Handlers",  "electricity", "HVAC",          0.148, 21_000, 0.30),
    ("Lighting - Interior",  "electricity", "Lighting",      0.148, 24_000, 0.10),
    ("Lighting - Garage",    "electricity", "Lighting",      0.148,  7_500, 0.05),
    ("Tenant Plug Loads",    "electricity", "Plug Loads",    0.148, 17_000, 0.08),
    ("Elevators & Pumps",    "electricity", "Other",         0.148,  6_200, 0.06),
    ("Boiler - Natural Gas", "gas",         "Heating",       1.320,  2_400, 0.85),
    ("Domestic Water",       "water",       "Domestic Water",0.012, 310_000, 0.12),
]

# Injected faults, so the alert panel has something real to find.
FAULTS = [
    ("HVAC - Chiller Plant", 0, 1.34),   # latest month: economizer stuck closed
    ("Lighting - Garage", 1, 1.28),      # month before: photocell failure, lights on 24/7
]


def seasonal_factor(month, swing, peak_month=7):
    """Cooling-shaped curve peaking in July, gentle enough to look like a real bill."""
    return 1.0 + swing * math.cos((month - peak_month) / 12.0 * 2 * math.pi)


def build(conn, end_period, months=24, seed=20260916):
    rng = random.Random(seed)
    site_id = db.add_site(conn, SITE["name"], SITE["floor_area_sqft"])
    meter_ids = {}
    for name, utility, system, rate, base, swing in METERS:
        meter_ids[name] = db.add_meter(conn, site_id, name, utility, system, unit_rate=rate)

    fault_by_meter = {}
    for name, months_back, multiplier in FAULTS:
        fault_by_meter.setdefault(name, {})[shift_period(end_period, -months_back)] = multiplier

    for name, utility, system, rate, base, swing in METERS:
        # Gas peaks in winter, everything else follows the cooling season.
        peak = 1 if utility == "gas" else 7
        for step in range(months - 1, -1, -1):
            period = shift_period(end_period, -step)
            month = int(period.split("-")[1])
            # A slow efficiency drift plus month-to-month noise.
            drift = 1.0 + 0.004 * step
            noise = rng.uniform(0.96, 1.04)
            usage = base * seasonal_factor(month, swing, peak) * drift * noise
            usage *= fault_by_meter.get(name, {}).get(period, 1.0)
            cost = usage * rate * rng.uniform(0.98, 1.05)
            db.upsert_reading(conn, meter_ids[name], period, round(usage, 1), round(cost, 2), source="seed")
    return site_id
