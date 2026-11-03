"""Read-only listing through storage, the local API and the table formatter."""
from contextlib import redirect_stdout
from datetime import datetime
import io
from pathlib import Path
import socket
import sqlite3
import sys
import tempfile
import unittest
from unittest.mock import patch
from zoneinfo import ZoneInfo

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "booking"))
import api
import client
from runtime import configuration, initialize_database
from storage import list_bookings
from table import print_bookings


class BookingListTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="booking-list-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.database = self.root / "booking.db"
        self.inventory = self.root / "booking.yml"
        self.inventory.write_text(yaml.safe_dump({"timezone": "Europe/Madrid", "servers": [{
            "name": socket.gethostname().split(".")[0], "id": "01",
            "managed_servers": ["incus-01", "incus-02"], "maximum_duration_hours": 5}]}))
        (self.root / "vars.yml").write_text(yaml.safe_dump({"paths": {
            "booking": str(self.inventory), "booking_db": str(self.database)}}))
        self.config = configuration(self.root, socket.gethostname())
        initialize_database(self.database, "01", ROOT / "booking/schema.sql")

    def stamp(self, value):
        return int(datetime.fromisoformat(value).replace(tzinfo=ZoneInfo("Europe/Madrid")).timestamp())

    def test_service_timezone_overrides_and_fallback(self):
        from booking_is_server import booking_timezone, load_inventory
        data = yaml.safe_load(self.inventory.read_text())
        data["servers"][0]["timezone"] = "America/New_York"
        data["servers"].append({"name": "other-booking", "id": "02",
                                "managed_servers": ["incus-03"], "maximum_duration_hours": 5,
                                "timezone": "Europe/Oslo"})
        self.inventory.write_text(yaml.safe_dump(data))
        config = configuration(self.root, socket.gethostname())
        self.assertEqual(config["timezone"], "America/New_York")
        self.assertEqual(booking_timezone(self.inventory, "incus-01"), "America/New_York")
        self.assertEqual(configuration(self.root, "other-booking")["timezone"], "Europe/Oslo")
        self.assertEqual(booking_timezone(self.inventory, "unlisted"), "Europe/Madrid")
        from storage import create_booking
        request = {"server": "incus-01", "date": "2099-01-10", "start": "14:00", "duration": "1h"}
        create_booking(config, "javier", request)
        result = list_bookings(config, "2099-01-10")
        self.assertEqual(result["timezone"], "America/New_York")
        expected = int(datetime(2099, 1, 10, 14, tzinfo=ZoneInfo("America/New_York")).timestamp())
        self.assertEqual(result["bookings"][0]["start_time"], expected)
        del data["servers"][0]["timezone"]
        self.inventory.write_text(yaml.safe_dump(data))
        self.assertEqual(configuration(self.root, socket.gethostname())["timezone"], "Europe/Madrid")
        data["servers"][0]["timezone"] = "invalid/timezone"
        self.inventory.write_text(yaml.safe_dump(data))
        with self.assertRaisesRegex(ValueError, "invalid booking timezone"):
            load_inventory(self.inventory)

    def insert(self, booking_id, start, end, cancelled=False):
        db = sqlite3.connect(self.database)
        self.addCleanup(db.close)
        with db:
            db.execute("INSERT INTO bookings VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                       (booking_id, "incus-01", "javier", self.stamp(start), self.stamp(end), 1,
                        2 if cancelled else None, "javier" if cancelled else None))

    def test_date_boundaries_sharing_and_read_only(self):
        self.insert("01-0001", "2026-10-24 23:30", "2026-10-25 00:30")
        self.insert("01-0002", "2026-10-25 23:30", "2026-10-26 00:30")
        self.insert("01-0003", "2026-10-24 23:00", "2026-10-25 00:00")
        self.insert("01-0004", "2026-10-26 00:00", "2026-10-26 01:00")
        self.insert("01-0005", "2026-10-25 14:00", "2026-10-25 15:00", cancelled=True)
        db = sqlite3.connect(self.database)
        self.addCleanup(db.close)
        with db:
            db.execute("INSERT INTO booking_shares VALUES ('01-0001', 'quico', 1)")
        before = self.database.read_bytes()
        result = list_bookings(self.config, "2026-10-25")
        self.assertEqual([row["booking_id"] for row in result["bookings"]], ["01-0001", "01-0002"])
        self.assertEqual(result["bookings"][0]["shared"], ["quico"])
        self.assertEqual(self.database.read_bytes(), before)
        self.config["server"]["managed_servers"] = ["incus-02"]
        self.assertEqual(list_bookings(self.config, "2026-10-25")["bookings"], [])

    def test_invalid_dates(self):
        for day in [None, "2026-2-01", "2026-02-30", "9999-12-31"]:
            with self.subTest(day=day), self.assertRaisesRegex(ValueError, "Invalid booking date"):
                list_bookings(self.config, day)

    def test_table_statuses_free_server_and_borders(self):
        self.insert("01-0001", "2026-10-25 13:00", "2026-10-25 14:00")
        self.insert("01-0002", "2026-10-25 14:00", "2026-10-25 15:00")
        self.insert("01-0003", "2026-10-25 15:00", "2026-10-25 16:00")
        output = io.StringIO()
        with redirect_stdout(output), patch("table.time.time", return_value=self.stamp("2026-10-25 14:30")):
            print_bookings(list_bookings(self.config, "2026-10-25"), history=True)
        lines = output.getvalue().splitlines()
        self.assertEqual(len(set(map(len, lines))), 1)
        self.assertEqual(lines[0], lines[2])
        self.assertEqual(lines[1][1:-1].strip(), self.config["server"]["name"] + " | Date: 2026-10-25 | Timezone: Europe/Madrid")
        self.assertTrue(lines[3].startswith("| Booking ID"))
        self.assertEqual(output.getvalue().count("Booking ID"), 1)
        for value in ["Booking ID", "Shared with", "Europe/Madrid", "01-0001"]:
            self.assertIn(value, output.getvalue())
        for value in ["Status", "Active", "Upcoming", "Expired", "Free", "incus-02", "01-0002", "01-0003"]:
            self.assertNotIn(value, output.getvalue())
        output = io.StringIO()
        with redirect_stdout(output), patch("table.time.time", return_value=self.stamp("2026-10-25 14:30")):
            print_bookings(list_bookings(self.config, "2026-10-25"))
        self.assertNotIn("Expired", output.getvalue())
        self.assertNotIn("01-0001", output.getvalue())
        self.assertIn("Active", output.getvalue())
        self.assertIn("Upcoming", output.getvalue())

    def test_history_includes_cancelled_and_keeps_status(self):
        self.insert("01-0001", "2026-10-25 13:00", "2026-10-25 14:00")
        self.insert("01-0002", "2026-10-25 15:00", "2026-10-25 16:00", cancelled=True)
        result = list_bookings(self.config, "2026-10-25", history=True)
        self.assertEqual(len(result["bookings"]), 2)
        output = io.StringIO()
        with redirect_stdout(output), patch("table.time.time", return_value=self.stamp("2026-10-25 14:30")):
            print_bookings(result, history=True)
        for value in ["Status", "Expired", "Cancelled", "01-0001", "01-0002"]:
            self.assertIn(value, output.getvalue())
        self.assertNotIn("Free", output.getvalue())
        self.assertNotIn("Upcoming", output.getvalue())

    def test_http_listing_and_client(self):
        self.insert("01-0001", "2026-10-25 13:00", "2026-10-25 14:00")
        path = self.root / "api.sock"
        server = api.start_api(self.root, path, group=None)
        self.addCleanup(api.stop_api, server)
        with patch.object(api, "peer_user", return_value="javier"):
            result = client.local_listing("2026-10-25", path)
            self.assertEqual(result["bookings"][0]["booking_id"], "01-0001")
            with self.assertRaisesRegex(ValueError, "Invalid booking date"):
                client.local_listing("2026-02-30", path)
            args = ["client.py", "--odev-path", str(self.root), "--list", "--date", "2026-10-25", "--history", "1"]
            with patch.object(sys, "argv", args), patch.object(client, "local_listing", return_value=result), redirect_stdout(io.StringIO()) as output:
                client.main()
            self.assertIn("01-0001", output.getvalue())
            self.inventory.write_text("servers: []\n")
            with self.assertRaisesRegex(ValueError, "Booking service unavailable"):
                client.local_listing("2026-10-25", path)
        with patch.object(api, "peer_user", side_effect=PermissionError("Permission denied: booking access")):
            with self.assertRaisesRegex(ValueError, "Permission denied"):
                client.local_listing("2026-10-25", path)


if __name__ == "__main__":
    unittest.main()
