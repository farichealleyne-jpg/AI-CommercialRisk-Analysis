#!/usr/bin/env python3
"""Energy & Utility Tracker - a small REST API plus the dashboard that reads it.

    python3 server.py --seed      # first run: demo site with two years of bills
    python3 server.py             # afterwards
    open http://localhost:8765

Standard library only: http.server for routing, sqlite3 for storage.
"""

import argparse
import json
import mimetypes
import os
import sys
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from energy import analytics, db, seed  # noqa: E402
from energy.importer import export_csv, import_csv  # noqa: E402

WEB_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")
MAX_BODY_BYTES = 8 * 1024 * 1024


class Handler(BaseHTTPRequestHandler):
    server_version = "EnergyTracker/1.0"
    db_path = None

    # --- plumbing -------------------------------------------------------

    def log_message(self, fmt, *args):
        if os.environ.get("ENERGY_QUIET"):
            return
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def conn(self):
        return db.init(db.connect(self.db_path))

    def send_json(self, payload, status=200):
        body = json.dumps(payload, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_error_json(self, message, status=400):
        self.send_json({"error": message}, status)

    def read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY_BYTES:
            raise ValueError("request body too large")
        return self.rfile.read(length).decode("utf-8") if length else ""

    def read_json(self):
        raw = self.read_body()
        if not raw:
            return {}
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ValueError("invalid JSON: %s" % exc)
        if not isinstance(data, dict):
            raise ValueError("expected a JSON object")
        return data

    def query(self):
        return parse_qs(urlparse(self.path).query)

    def int_param(self, name, default=None):
        values = self.query().get(name)
        if not values:
            return default
        try:
            return int(values[0])
        except ValueError:
            raise ValueError("%s must be a whole number" % name)

    # --- routing --------------------------------------------------------

    def do_GET(self):
        route = urlparse(self.path).path
        try:
            if route.startswith("/api/"):
                return self.api_get(route)
            return self.serve_static(route)
        except ValueError as exc:
            return self.send_error_json(str(exc))

    def do_POST(self):
        route = urlparse(self.path).path
        try:
            return self.api_post(route)
        except ValueError as exc:
            return self.send_error_json(str(exc))

    def do_DELETE(self):
        route = urlparse(self.path).path
        if route.startswith("/api/readings/"):
            try:
                reading_id = int(route.rsplit("/", 1)[-1])
            except ValueError:
                return self.send_error_json("reading id must be a whole number")
            with closing(self.conn()) as conn:
                removed = db.delete_reading(conn, reading_id)
            if not removed:
                return self.send_error_json("no reading with id %d" % reading_id, 404)
            return self.send_json({"deleted": reading_id})
        return self.send_error_json("unknown endpoint", 404)

    def api_get(self, route):
        site_id = self.int_param("site")
        with closing(self.conn()) as conn:
            if route == "/api/health":
                return self.send_json({"status": "ok"})
            if route == "/api/sites":
                return self.send_json({"sites": db.list_sites(conn)})
            if route == "/api/meters":
                return self.send_json({"meters": db.list_meters(conn, site_id)})
            if route == "/api/readings":
                readings = db.list_readings(conn, site_id=site_id,
                                            utility=(self.query().get("utility") or [None])[0],
                                            limit=self.int_param("limit"))
                return self.send_json({"readings": readings})
            if route == "/api/dashboard":
                data = analytics.dashboard(
                    conn,
                    site_id=site_id or self.default_site_id(conn),
                    months=self.int_param("months", 12),
                    annual_budget=self.float_param("budget"),
                )
                data["utilities"] = db.UTILITIES
                data["sites"] = db.list_sites(conn)
                return self.send_json(data)
            if route == "/api/export.csv":
                readings = db.list_readings(conn, site_id=site_id)
                return self.send_csv(export_csv(readings), "energy-readings.csv")
        return self.send_error_json("unknown endpoint", 404)

    def api_post(self, route):
        with closing(self.conn()) as conn:
            if route == "/api/sites":
                payload = self.read_json()
                name = (payload.get("name") or "").strip()
                if not name:
                    return self.send_error_json("name is required")
                site_id = db.add_site(conn, name, payload.get("floor_area_sqft"))
                return self.send_json({"id": site_id}, 201)

            if route == "/api/meters":
                payload = self.read_json()
                for field in ("site_id", "name", "utility", "system"):
                    if not payload.get(field):
                        return self.send_error_json("%s is required" % field)
                meter_id = db.add_meter(conn, int(payload["site_id"]), payload["name"].strip(),
                                        payload["utility"], payload["system"],
                                        unit_rate=float(payload.get("unit_rate") or 0))
                return self.send_json({"id": meter_id}, 201)

            if route == "/api/readings":
                payload = self.read_json()
                if not payload.get("meter_id"):
                    return self.send_error_json("meter_id is required")
                if payload.get("consumption") in (None, ""):
                    return self.send_error_json("consumption is required")
                cost = payload.get("cost")
                db.upsert_reading(conn, int(payload["meter_id"]), payload.get("period", ""),
                                  float(payload["consumption"]),
                                  float(cost) if cost not in (None, "") else None,
                                  source=payload.get("source", "manual"))
                return self.send_json({"status": "saved"}, 201)

            if route == "/api/import":
                site_id = self.int_param("site") or self.default_site_id(conn)
                if not site_id:
                    return self.send_error_json("create a site before importing readings")
                result = import_csv(conn, self.read_body(), site_id)
                return self.send_json(result, 200 if result["imported"] else 400)
        return self.send_error_json("unknown endpoint", 404)

    def float_param(self, name):
        values = self.query().get(name)
        if not values:
            return None
        try:
            return float(values[0])
        except ValueError:
            raise ValueError("%s must be a number" % name)

    @staticmethod
    def default_site_id(conn):
        sites = db.list_sites(conn)
        return sites[0]["id"] if sites else None

    # --- static files ---------------------------------------------------

    def send_csv(self, text, filename):
        body = text.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/csv; charset=utf-8")
        self.send_header("Content-Disposition", 'attachment; filename="%s"' % filename)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def serve_static(self, route):
        relative = "index.html" if route in ("/", "") else route.lstrip("/")
        target = os.path.normpath(os.path.join(WEB_ROOT, relative))
        # Keep traversal inside web/ regardless of what the URL asks for.
        if not target.startswith(WEB_ROOT + os.sep) or not os.path.isfile(target):
            return self.send_error_json("not found", 404)
        content_type = mimetypes.guess_type(target)[0] or "application/octet-stream"
        with open(target, "rb") as handle:
            body = handle.read()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)


def bootstrap_demo(db_path, end_period):
    conn = db.init(db.connect(db_path))
    if db.list_sites(conn):
        print("Database already has a site; skipping seed.")
        return
    seed.build(conn, end_period)
    readings = db.list_readings(conn)
    print("Seeded %s with %d readings across %d meters."
          % (seed.SITE["name"], len(readings), len({r["meter_id"] for r in readings})))
    conn.close()


def main(argv=None):
    parser = argparse.ArgumentParser(description="Energy & utility consumption tracker")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--db", default=db.DEFAULT_DB_PATH, help="path to the SQLite file")
    parser.add_argument("--seed", action="store_true", help="load two years of demo readings")
    parser.add_argument("--seed-through", default=None, metavar="YYYY-MM",
                        help="last month of demo data (default: the current month)")
    args = parser.parse_args(argv)

    if args.seed:
        from datetime import date
        end = args.seed_through or date.today().strftime("%Y-%m")
        db.validate_period(end)
        bootstrap_demo(args.db, end)

    Handler.db_path = args.db
    httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    print("Energy tracker on http://%s:%d  (database: %s)" % (args.host, args.port, args.db))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
