"""Cancellation permissions, confirmation and preservation of history."""
from contextlib import redirect_stdout
import io
import sqlite3
import sys
import unittest
from unittest.mock import patch

import test_booking_add

api = test_booking_add.api
client = test_booking_add.client
from storage import cancel_booking, create_booking, list_bookings


class BookingCancelTest(unittest.TestCase):
    setUp = test_booking_add.BookingAddTest.setUp

    def test_owner_admin_and_history(self):
        booking = create_booking(self.config, "javier", self.request)
        with self.assertRaises(PermissionError):
            cancel_booking(self.config, "quico", booking, confirm=True)
        cancel_booking(self.config, "javier", booking)
        self.assertEqual(len(list_bookings(self.config, self.request["date"])["bookings"]), 1)
        cancel_booking(self.config, "admin", booking, administrator=True, confirm=True)
        self.assertEqual(list_bookings(self.config, self.request["date"])["bookings"], [])
        history = list_bookings(self.config, self.request["date"], history=True)["bookings"]
        self.assertIsNotNone(history[0]["cancelled_at"])
        self.assertEqual(history[0]["shared"], ["quico"])
        with sqlite3.connect(self.database) as db:
            self.assertEqual(db.execute("SELECT cancelled_by FROM bookings").fetchone()[0], "admin")
            self.assertEqual(db.execute("SELECT last_sequence FROM booking_metadata").fetchone()[0], 1)
        with self.assertRaisesRegex(ValueError, "already cancelled"):
            cancel_booking(self.config, "javier", booking, confirm=True)

    def test_missing_expired_and_active(self):
        with self.assertRaisesRegex(ValueError, "Invalid booking"):
            cancel_booking(self.config, "javier", "01-9999", confirm=True)
        booking = create_booking(self.config, "javier", self.request)
        with sqlite3.connect(self.database) as db:
            start, end = db.execute("SELECT start_time, end_time FROM bookings").fetchone()
        with patch("storage.time.time", return_value=end), self.assertRaisesRegex(ValueError, "Booking expired"):
            cancel_booking(self.config, "javier", booking, confirm=True)
        with patch("storage.time.time", return_value=start + 1):
            cancel_booking(self.config, "javier", booking, confirm=True)

    def test_client_confirmation(self):
        booking = {"booking_id": "01-0001", "server": "incus-01", "start_time": 1900000000,
                   "end_time": 1900003600, "timezone": "UTC"}
        args = ["client.py", "--odev-path", str(self.root), "--cancel", "01-0001"]
        for answer in ["", "n", "y"]:
            with self.subTest(answer=answer), patch.object(sys, "argv", args), \
                    patch.object(client, "local_cancellation", return_value=booking) as request, \
                    patch("builtins.input", return_value=answer), redirect_stdout(io.StringIO()) as output:
                client.main()
                self.assertEqual(request.call_count, 2 if answer == "y" else 1)
                self.assertEqual("Booking cancelled:" in output.getvalue(), answer == "y")

    def test_api_authentication_and_cancellation(self):
        booking = create_booking(self.config, "javier", self.request)
        path = self.root / "api.sock"
        server = api.start_api(self.root, path, group=None)
        self.addCleanup(api.stop_api, server)
        with patch.object(api, "peer_user", return_value="quico"), patch.object(api, "is_administrator", return_value=False):
            with self.assertRaisesRegex(ValueError, "Permission denied"):
                client.local_cancellation(booking, confirm=True, path=path)
        with patch.object(api, "peer_user", return_value="javier"), patch.object(api, "is_administrator", return_value=False):
            self.assertEqual(client.local_cancellation(booking, path=path)["server"], "incus-01")
            client.local_cancellation(booking, confirm=True, path=path)
            result = client.local_listing(self.request["date"], path=path, history=True)
            self.assertIsNotNone(result["bookings"][0]["cancelled_at"])


if __name__ == "__main__":
    unittest.main()
