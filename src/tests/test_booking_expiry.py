"""Session expiry safety without changing any live sessions."""
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "booking"))
import expiry
import test_booking_list
from storage import booking_access_users


class BookingExpiryTest(unittest.TestCase):
    def run_sweep(self, jobs=True, allowed=(), dry_run=False, fail_lookup=False, changed=False):
        config = {"name": "booking-one", "terminate_jobs": jobs}
        properties = {
            "s1": {"User": "1001", "Service": "sshd", "Leader": "101"},
            "s2": {"User": "1002", "Service": "sshd", "Leader": "102"},
            "s0": {"User": "0", "Service": "sshd", "Leader": "103"},
        }
        actions = []
        def command(*args):
            if args[:2] == ("loginctl", "list-sessions"):
                return "s1 1001 first\ns2 1002 admin\ns0 0 root\n"
            if args[:2] == ("loginctl", "list-users"):
                return "0 root\n1001 first\n1002 admin\n1003 detached\n999 system\n"
            actions.append(args)
            return ""
        def user(uid):
            return SimpleNamespace(pw_name={0: "root", 999: "system", 1001: "first",
                                            1002: "admin", 1003: "detached"}[uid])
        sequence = [config, None] if changed else None
        with patch.object(expiry, "settings", side_effect=sequence, return_value=config), \
                patch.object(expiry, "remote_lookup", side_effect=ValueError("unreachable") if fail_lookup else None,
                             return_value=json.dumps({"users": list(allowed)})), \
                patch.object(expiry.Path, "read_text", return_value="UID_MIN 1000\n"), \
                patch.object(expiry, "command", side_effect=command), \
                patch.object(expiry, "session_properties", side_effect=lambda session: properties[session]), \
                patch.object(expiry.pwd, "getpwuid", side_effect=user), \
                patch.object(expiry, "require_user"), \
                patch.object(expiry, "is_administrator", side_effect=lambda name: name == "admin"), \
                redirect_stdout(io.StringIO()):
            if fail_lookup:
                with self.assertRaises(ValueError):
                    expiry.sweep(ROOT, dry_run)
            else:
                expiry.sweep(ROOT, dry_run)
        return actions

    def test_jobs_root_admin_and_system_exemptions(self):
        self.assertEqual(self.run_sweep(), [
            ("loginctl", "terminate-user", "1001"),
            ("loginctl", "terminate-user", "1003")])

    def test_valid_booking_preserves_sessions_and_jobs(self):
        self.assertEqual(self.run_sweep(allowed=["first", "detached"]), [])

    def test_false_disconnects_only_ssh_session_leaders(self):
        self.assertEqual(self.run_sweep(jobs=False), [
            ("loginctl", "kill-session", "--kill-whom=leader", "--signal=SIGTERM", "s1")])

    def test_outage_dry_run_and_configuration_change_do_not_kill(self):
        self.assertEqual(self.run_sweep(fail_lookup=True), [])
        self.assertEqual(self.run_sweep(dry_run=True), [])
        self.assertEqual(self.run_sweep(changed=True), [])

    def test_unmanaged_host_performs_no_lookup(self):
        with patch.object(expiry, "settings", return_value=None), patch.object(expiry, "remote_lookup") as lookup:
            expiry.sweep(ROOT)
            lookup.assert_not_called()


class BookingExpiryStorageTest(unittest.TestCase):
    setUp = test_booking_list.BookingListTest.setUp
    stamp = test_booking_list.BookingListTest.stamp
    insert = test_booking_list.BookingListTest.insert

    def test_authorization_snapshot_owner_shared_and_expiry(self):
        import sqlite3
        self.insert("01-0001", "2026-10-25 13:00", "2026-10-25 14:00")
        self.insert("01-0002", "2026-10-25 14:00", "2026-10-25 15:00", cancelled=True)
        connection = sqlite3.connect(self.database)
        self.addCleanup(connection.close)
        with connection:
            connection.execute("INSERT INTO booking_shares VALUES ('01-0001', 'jmoya82', 1)")
        with patch("storage.time.time", return_value=self.stamp("2026-10-25 13:30")):
            self.assertEqual(booking_access_users(self.config, "incus-01"), ["javier", "jmoya82"])
            self.assertEqual(booking_access_users(self.config, "incus-02"), [])
        with patch("storage.time.time", return_value=self.stamp("2026-10-25 14:00")):
            self.assertEqual(booking_access_users(self.config, "incus-01"), [])


if __name__ == "__main__":
    unittest.main()
