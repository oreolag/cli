"""Database initialization and daemon role changes without a running systemd."""
from contextlib import redirect_stdout
import importlib.util
import io
from pathlib import Path
import signal
import queue
import socket
import sqlite3
import subprocess
import sys
import tempfile
import threading
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("booking_runtime", ROOT / "booking/runtime.py")
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)
sys.modules["runtime"] = runtime
spec = importlib.util.spec_from_file_location("booking_daemon", ROOT / "booking/daemon.py")
daemon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(daemon)


class BookingRuntimeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.database = self.root / "state/booking.db"
        self.entry = {"name": socket.gethostname().split(".")[0], "id": "01",
                      "managed_servers": ["example-managed"], "maximum_duration_hours": 5}
        self.inventory = self.root / "booking.yml"
        self.inventory.write_text(yaml.safe_dump({"servers": [self.entry]}))
        (self.root / "vars.yml").write_text(yaml.safe_dump({"paths": {
            "booking": str(self.inventory), "booking_db": str(self.database)}}))
        (self.root / "booking").mkdir()
        (self.root / "booking/schema.sql").write_text((ROOT / "booking/schema.sql").read_text())

    def initialize(self, service_id="01"):
        return runtime.initialize_database(self.database, service_id, ROOT / "booking/schema.sql")

    def test_initialization_and_restarts_preserve_reservations(self):
        self.assertTrue(self.initialize())
        with sqlite3.connect(self.database) as db:
            db.execute("UPDATE booking_metadata SET last_sequence=10000")
            db.execute("INSERT INTO bookings VALUES ('01-10000','incus-01','javier',100,200,50,NULL,NULL)")
        before = self.database.read_bytes()
        self.assertFalse(self.initialize())
        self.assertEqual(before, self.database.read_bytes())
        with self.assertRaisesRegex(ValueError, "service ID"):
            self.initialize("02")
        self.assertEqual(before, self.database.read_bytes())

    def test_wrong_schema_is_not_replaced(self):
        self.initialize()
        with sqlite3.connect(self.database) as db:
            db.execute("PRAGMA user_version=2")
        before = self.database.read_bytes()
        with self.assertRaisesRegex(ValueError, "schema version"):
            self.initialize()
        self.assertEqual(before, self.database.read_bytes())

    def test_concurrent_initialization(self):
        code = ("import sys; sys.path.insert(0, sys.argv[1]); "
                "from runtime import initialize_database; "
                "print(initialize_database(sys.argv[2], '01', sys.argv[3]))")
        processes = [subprocess.Popen(
            [sys.executable, "-B", "-c", code, str(ROOT / "booking"), str(self.database),
             str(ROOT / "booking/schema.sql")], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True) for _ in range(3)]
        outputs = []
        for process in processes:
            out, err = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, err)
            outputs.append(out.strip())
        self.assertEqual(outputs.count("True"), 1)
        self.assertEqual(outputs.count("False"), 2)

    def test_failed_initialization_does_not_publish_database(self):
        schema = self.root / "invalid.sql"
        schema.write_text("not valid SQL")
        with self.assertRaises(sqlite3.Error):
            runtime.initialize_database(self.database, "01", schema)
        self.assertFalse(self.database.exists())
        self.assertTrue(self.initialize())

    def test_configuration_active_unchanged_idle(self):
        config = runtime.configuration(self.root, self.entry["name"])
        output = io.StringIO()
        with redirect_stdout(output):
            current = daemon.apply_configuration(config, None, self.root)
        self.assertIn("created", output.getvalue())
        before = self.database.read_bytes()
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(daemon.apply_configuration(config, current, self.root), current)
        self.assertEqual(output.getvalue(), "")
        config["server"] = None
        with redirect_stdout(output):
            daemon.apply_configuration(config, current, self.root)
        self.assertIn("idle", output.getvalue())
        self.assertEqual(before, self.database.read_bytes())

    def test_running_daemon_detects_role_changes_and_recovers(self):
        self.inventory.write_text("servers: []\n")
        process = subprocess.Popen([sys.executable, "-B", str(ROOT / "booking/daemon.py"),
                                    "--odev-path", str(self.root), "--interval", "0.05"],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        events = queue.Queue()
        for stream in [process.stdout, process.stderr]:
            threading.Thread(target=lambda pipe: [events.put(line) for line in pipe],
                             args=(stream,), daemon=True).start()
        def update(content):
            temporary = self.root / "next.yml"
            temporary.write_text(content)
            temporary.replace(self.inventory)
        try:
            self.assertIn("idle", events.get(timeout=5))
            self.assertFalse(self.database.exists())
            update("servers: [")
            self.assertIn("ERROR:", events.get(timeout=5))
            update(yaml.safe_dump({"servers": [self.entry]}))
            # YAML errors may contain multiple diagnostic lines.
            for _ in range(20):
                if "Booking service ready" in events.get(timeout=5):
                    break
            else:
                self.fail("daemon did not recover")
            self.assertTrue(self.database.exists())
            before = self.database.read_bytes()
            update("servers: []\n")
            self.assertIn("idle", events.get(timeout=5))
            self.assertIsNone(process.poll())
            self.assertEqual(before, self.database.read_bytes())
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=5)
            self.assertEqual(process.returncode, 0)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdout.close()
            process.stderr.close()

    def test_invalid_inventory_fails_before_any_service_action(self):
        self.inventory.write_text("servers: [")
        with self.assertRaises(yaml.YAMLError):
            runtime.configuration(self.root, self.entry["name"])
        self.assertFalse(self.database.exists())

    def test_daemon_initializes_and_handles_shutdown(self):
        process = subprocess.Popen([sys.executable, "-B", str(ROOT / "booking/daemon.py"),
                                    "--odev-path", str(self.root)],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertIn("Booking database created:", process.stdout.readline())
            self.assertIn("API not implemented", process.stdout.readline())
            process.send_signal(signal.SIGTERM)
            out, err = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, err)
            self.assertTrue(self.database.exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


if __name__ == "__main__":
    unittest.main()
