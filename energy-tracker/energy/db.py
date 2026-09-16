"""SQLite storage for meters and utility readings.

Only the Python standard library is used so the tracker runs anywhere a
Python 3.9+ interpreter exists, with no install step.
"""

import os
import sqlite3
from datetime import datetime, timezone

DEFAULT_DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "energy.db")

SCHEMA = """
CREATE TABLE IF NOT EXISTS sites (
    id              INTEGER PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    floor_area_sqft REAL,
    created_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS meters (
    id        INTEGER PRIMARY KEY,
    site_id   INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    name      TEXT NOT NULL,
    utility   TEXT NOT NULL,
    unit      TEXT NOT NULL,
    system    TEXT NOT NULL,
    unit_rate REAL NOT NULL DEFAULT 0,
    active    INTEGER NOT NULL DEFAULT 1,
    UNIQUE (site_id, name)
);

CREATE TABLE IF NOT EXISTS readings (
    id          INTEGER PRIMARY KEY,
    meter_id    INTEGER NOT NULL REFERENCES meters(id) ON DELETE CASCADE,
    period      TEXT NOT NULL,
    consumption REAL NOT NULL,
    cost        REAL,
    source      TEXT NOT NULL DEFAULT 'manual',
    recorded_at TEXT NOT NULL,
    UNIQUE (meter_id, period)
);

CREATE INDEX IF NOT EXISTS idx_readings_period ON readings (period);
CREATE INDEX IF NOT EXISTS idx_meters_site ON meters (site_id);
"""

# Utilities the tracker understands: unit, kg CO2e per unit, display label.
UTILITIES = {
    "electricity": {"unit": "kWh", "co2e_per_unit": 0.371, "label": "Electricity"},
    "gas":         {"unit": "therms", "co2e_per_unit": 5.302, "label": "Natural gas"},
    "water":       {"unit": "gal", "co2e_per_unit": 0.0021, "label": "Water"},
}


def now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def connect(db_path=None):
    """Open a connection with foreign keys on and dict-like rows."""
    path = db_path or os.environ.get("ENERGY_DB", DEFAULT_DB_PATH)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init(conn):
    conn.executescript(SCHEMA)
    conn.commit()
    return conn


def add_site(conn, name, floor_area_sqft=None):
    cur = conn.execute(
        "INSERT INTO sites (name, floor_area_sqft, created_at) VALUES (?, ?, ?)",
        (name, floor_area_sqft, now_iso()),
    )
    conn.commit()
    return cur.lastrowid


def add_meter(conn, site_id, name, utility, system, unit_rate=0.0, unit=None):
    if utility not in UTILITIES:
        raise ValueError("unknown utility: %s" % utility)
    cur = conn.execute(
        "INSERT INTO meters (site_id, name, utility, unit, system, unit_rate) VALUES (?, ?, ?, ?, ?, ?)",
        (site_id, name, utility, unit or UTILITIES[utility]["unit"], system, unit_rate),
    )
    conn.commit()
    return cur.lastrowid


def upsert_reading(conn, meter_id, period, consumption, cost=None, source="manual"):
    """Record a meter reading for a billing month (YYYY-MM), replacing any prior value."""
    validate_period(period)
    if consumption < 0:
        raise ValueError("consumption cannot be negative")
    conn.execute(
        """
        INSERT INTO readings (meter_id, period, consumption, cost, source, recorded_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT (meter_id, period) DO UPDATE SET
            consumption = excluded.consumption,
            cost        = excluded.cost,
            source      = excluded.source,
            recorded_at = excluded.recorded_at
        """,
        (meter_id, period, consumption, cost, source, now_iso()),
    )
    conn.commit()


def validate_period(period):
    try:
        datetime.strptime(period, "%Y-%m")
    except (TypeError, ValueError):
        raise ValueError("period must look like YYYY-MM, got %r" % (period,))
    return period


def list_sites(conn):
    return [dict(r) for r in conn.execute("SELECT * FROM sites ORDER BY name")]


def list_meters(conn, site_id=None):
    sql = "SELECT * FROM meters"
    args = []
    if site_id:
        sql += " WHERE site_id = ?"
        args.append(site_id)
    sql += " ORDER BY system, name"
    return [dict(r) for r in conn.execute(sql, args)]


def list_readings(conn, site_id=None, utility=None, limit=None):
    """Readings joined to their meter, newest period first, cost always resolved."""
    sql = """
        SELECT r.id, r.period, r.consumption, r.cost, r.source, r.recorded_at,
               m.id AS meter_id, m.name AS meter, m.utility, m.unit, m.system,
               m.unit_rate, m.site_id
        FROM readings r
        JOIN meters m ON m.id = r.meter_id
    """
    where, args = [], []
    if site_id:
        where.append("m.site_id = ?")
        args.append(site_id)
    if utility:
        where.append("m.utility = ?")
        args.append(utility)
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY r.period DESC, m.system, m.name"
    if limit:
        sql += " LIMIT ?"
        args.append(limit)
    rows = []
    for r in conn.execute(sql, args):
        row = dict(r)
        row["cost"] = resolved_cost(row)
        rows.append(row)
    return rows


def resolved_cost(reading):
    """A reading's cost: the billed figure when we have one, else rate x usage."""
    if reading.get("cost") is not None:
        return float(reading["cost"])
    return float(reading["consumption"]) * float(reading.get("unit_rate") or 0.0)


def delete_reading(conn, reading_id):
    cur = conn.execute("DELETE FROM readings WHERE id = ?", (reading_id,))
    conn.commit()
    return cur.rowcount
