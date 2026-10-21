"""Validate the booking schema without creating a persistent database."""
from pathlib import Path
import sqlite3
import unittest


SCHEMA = Path(__file__).resolve().parents[2] / "booking/schema.sql"


class BookingSchemaTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.addCleanup(self.db.close)
        self.db.executescript(SCHEMA.read_text())

    def booking(self, booking_id="01-0001", start=100, end=200):
        self.db.execute(
            "INSERT INTO bookings (booking_id, server, owner, start_time, end_time, created_at) "
            "VALUES (?, 'incus-01', 'javier', ?, ?, 50)", (booking_id, start, end))

    def test_shared_booking_reference_and_duplicates(self):
        self.booking()
        self.db.execute("INSERT INTO booking_shares VALUES ('01-0001', 'quico', 60)")
        self.assertEqual(self.db.execute(
            "SELECT b.booking_id FROM bookings b JOIN booking_shares s USING (booking_id)"
        ).fetchone()[0], "01-0001")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO booking_shares VALUES ('01-0001', 'quico', 61)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO booking_shares VALUES ('01-9999', 'quico', 61)")

    def test_booking_constraints(self):
        self.booking()
        with self.assertRaises(sqlite3.IntegrityError):
            self.booking()
        with self.assertRaises(sqlite3.IntegrityError):
            self.booking("01-0002", start=200, end=100)
        with self.assertRaises(sqlite3.IntegrityError):
            self.booking("01-0003", start=100, end=100)

    def test_cancellation_retains_booking_and_shares(self):
        self.booking()
        self.db.execute("INSERT INTO booking_shares VALUES ('01-0001', 'quico', 60)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE bookings SET cancelled_at = 70")
        self.db.execute("UPDATE bookings SET cancelled_at = 70, cancelled_by = 'javier'")
        self.assertEqual(self.db.execute("SELECT count(*) FROM bookings").fetchone()[0], 1)
        self.assertEqual(self.db.execute("SELECT count(*) FROM booking_shares").fetchone()[0], 1)

    def test_service_metadata_and_expanding_sequence(self):
        self.db.execute("INSERT INTO booking_metadata (singleton, service_id) VALUES (1, '01')")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO booking_metadata (singleton, service_id) VALUES (2, '02')")
        self.db.execute("UPDATE booking_metadata SET last_sequence = 10000")
        self.booking("01-10000")
        self.assertEqual(self.db.execute("SELECT service_id, last_sequence FROM booking_metadata").fetchone(),
                         ("01", 10000))
        self.assertEqual(self.db.execute("PRAGMA user_version").fetchone()[0], 1)


if __name__ == "__main__":
    unittest.main()
