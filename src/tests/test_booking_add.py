"""Storage and HTTP integration for booking add; no remote services required."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
import io
from pathlib import Path
import socket
import sqlite3
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "booking"))
import api
import client
from runtime import configuration, initialize_database
from storage import BookingConflict, create_booking


class BookingAddTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="booking-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.database = self.root / "booking.db"
        self.inventory = self.root / "booking.yml"
        self.entry = {"name": socket.gethostname().split(".")[0], "id": "01",
                      "managed_servers": ["incus-01"], "maximum_duration_hours": 5}
        self.inventory.write_text(yaml.safe_dump({"timezone": "UTC", "servers": [self.entry]}))
        (self.root / "vars.yml").write_text(yaml.safe_dump({"paths": {
            "booking": str(self.inventory), "booking_db": str(self.database)}}))
        self.config = configuration(self.root, self.entry["name"])
        initialize_database(self.database, "01", ROOT / "booking/schema.sql")
        tomorrow = (datetime.now(timezone.utc) + timedelta(days=1)).date().isoformat()
        self.request = {"server": "incus-01", "date": tomorrow, "start": "14:15",
                        "duration": "2h", "shared": ["quico", "quico", "javier"]}

    def test_create_and_share_then_adjacent_booking(self):
        self.assertEqual(create_booking(self.config, "javier", self.request), "01-0001")
        with sqlite3.connect(self.database) as db:
            row = db.execute("SELECT booking_id, server, owner, start_time, end_time FROM bookings").fetchone()
            self.assertEqual(row[:3], ("01-0001", "incus-01", "javier"))
            self.assertEqual(row[4] - row[3], 7200)
            self.assertEqual(db.execute("SELECT username FROM booking_shares").fetchall(), [("quico",)])
        self.assertEqual(create_booking(self.config, "javier", {**self.request, "start": "16:15"}), "01-0002")

    def test_duration_units(self):
        from booking_is_server import duration_seconds
        for value, expected in [("5m", 300), ("60m", 3600), ("1h", 3600), ("2h", 7200), ("300m", 18000)]:
            self.assertEqual(duration_seconds(value, 5), expected)
        create_booking(self.config, "javier", {**self.request, "duration": "5m"})
        with sqlite3.connect(self.database) as db:
            start, end = db.execute("SELECT start_time, end_time FROM bookings").fetchone()
            self.assertEqual(end - start, 300)

    def test_concurrent_overlap_and_sequence(self):
        def reserve(_):
            try:
                return create_booking(self.config, "javier", self.request)
            except BookingConflict:
                return "conflict"
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(reserve, range(4)))
        self.assertEqual(results.count("01-0001"), 1)
        self.assertEqual(results.count("conflict"), 3)
        with sqlite3.connect(self.database) as db:
            self.assertEqual(db.execute("SELECT last_sequence FROM booking_metadata").fetchone()[0], 1)

    def test_rejections_leave_no_rows_or_sequence_changes(self):
        requests = [{**self.request, "duration": value} for value in ["0m", "-1h", "6h", "301m", "NaN", "0.001h", "1", "5M", "m"]]
        requests += [{**self.request, "start": value} for value in ["6:55", "06.55", "24:00"]]
        requests += [{**self.request, "server": "other"}, {**self.request, "date": "2020-01-01"}]
        for request in requests:
            with self.subTest(request=request), self.assertRaises(ValueError):
                create_booking(self.config, "javier", request)
        with sqlite3.connect(self.database) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM bookings").fetchone()[0], 0)
            self.assertEqual(db.execute("SELECT last_sequence FROM booking_metadata").fetchone()[0], 0)

    def test_timezone_and_sequence_expansion(self):
        self.config["timezone"] = "Europe/Madrid"
        with sqlite3.connect(self.database) as db:
            db.execute("UPDATE booking_metadata SET last_sequence=9999")
        self.assertEqual(create_booking(self.config, "javier", self.request), "01-10000")
        from zoneinfo import ZoneInfo
        expected = int(datetime.strptime(self.request["date"] + " 14:15", "%Y-%m-%d %H:%M")
                       .replace(tzinfo=ZoneInfo("Europe/Madrid")).timestamp())
        with sqlite3.connect(self.database) as db:
            self.assertEqual(db.execute("SELECT start_time FROM bookings").fetchone()[0], expected)

    def test_http_creation_permissions_and_current_role(self):
        path = self.root / "api.sock"
        server = api.start_api(self.root, path, group=None)
        self.addCleanup(api.stop_api, server)
        def require_user(user):
            if user not in ["javier", "quico"]:
                raise ValueError(f"Invalid user: {user}")
        with patch.object(api, "peer_user", return_value="javier"), patch.object(api, "require_user", side_effect=require_user):
            self.assertEqual(client.local_request(self.request, path), "01-0001")
            with self.assertRaisesRegex(ValueError, "Server already booked"):
                client.local_request(self.request, path)
            with self.assertRaisesRegex(ValueError, "Invalid booking request"):
                client.local_request({**self.request, "owner": "someone-else"}, path)
            with self.assertRaisesRegex(ValueError, "Invalid user"):
                client.local_request({**self.request, "shared": ["unknown"]}, path)
            self.inventory.write_text("servers: []\n")
            with self.assertRaisesRegex(ValueError, "Booking service unavailable"):
                client.local_request(self.request, path)
        with patch.object(api, "peer_user", side_effect=PermissionError("Permission denied: booking access")):
            with self.assertRaisesRegex(ValueError, "Permission denied"):
                client.local_request(self.request, path)
        with sqlite3.connect(self.database) as db:
            self.assertEqual(db.execute("SELECT count(*) FROM bookings").fetchone()[0], 1)

    def test_client_uses_only_local_api_and_does_not_claim_owner(self):
        args = ["client.py", "--odev-path", str(self.root), "--server", "incus-01",
                "--date", self.request["date"], "--start", "14:15", "--duration", "2h"]
        with patch.object(sys, "argv", args), patch.object(client, "local_request", return_value="01-0001") as api_call:
            output = io.StringIO()
            with redirect_stdout(output):
                client.main()
        self.assertEqual(output.getvalue(), "Booking created: 01-0001\n")
        self.assertEqual(api_call.call_args.args[0]["server"], "incus-01")
        self.assertNotIn("owner", api_call.call_args.args[0])

    def test_managed_client_routes_to_assigned_service(self):
        self.entry["name"] = "booking-host"
        other = {**self.entry, "name": "other-booking", "id": "02", "managed_servers": ["incus-03"]}
        self.inventory.write_text(yaml.safe_dump({"servers": [self.entry, other]}))
        args = ["client.py", "--odev-path", str(self.root), "--server", "incus-03",
                "--date", self.request["date"], "--start", "14:15", "--duration", "2h"]
        with patch.object(sys, "argv", args), patch.object(client.socket, "gethostname", return_value="incus-01"), \
                patch.object(client, "run_remote_booking") as remote, patch.object(client, "local_request") as local:
            client.main()
        root, peers, command, operation = remote.call_args.args
        self.assertEqual((root, peers, operation), (self.root, ["other-booking"], "create booking"))
        self.assertIn("--local-only", command)
        self.assertEqual(command[command.index("--server") + 1], "incus-03")
        local.assert_not_called()

    def test_client_rejects_unassigned_host_and_unknown_target(self):
        self.entry["name"] = "booking-host"
        other = {**self.entry, "name": "other-booking", "id": "02", "managed_servers": ["incus-02"]}
        self.inventory.write_text(yaml.safe_dump({"servers": [self.entry, other]}))
        cases = [("unassigned", "incus-01", "Command not available: odev booking"),
                 ("incus-01", "incus-99", "Invalid server: incus-99"),
                 ("booking-host", "incus-99", "Invalid server: incus-99")]
        for hostname, target, error in cases:
            args = ["client.py", "--odev-path", str(self.root), "--server", target]
            with self.subTest(hostname=hostname), patch.object(sys, "argv", args), \
                    patch.object(client.socket, "gethostname", return_value=hostname), \
                    patch.object(client, "local_request") as api_call:
                with self.assertRaisesRegex(ValueError, error):
                    client.main()
                api_call.assert_not_called()


if __name__ == "__main__":
    unittest.main()
