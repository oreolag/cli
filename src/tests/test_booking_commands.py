"""Run with PyYAML installed: python3 -m unittest discover -s src/tests."""
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]


class BookingCommandsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Path(self.temp.name) / "booking.yml"
        self.local = socket.gethostname().split(".")[0]
        self.env = {**os.environ, "BOOKING_DB_FILE": str(self.db), "ODEV_PATH": str(ROOT)}

    def inventory(self, name, machines):
        self.db.write_text(yaml.safe_dump({"servers": [{
            "name": name, "managed_servers": machines,
            "maximum_duration_hours": 5, "terminate_jobs": True,
        }]}))

    def run_command(self, *args, script="cmd/booking.sh"):
        return subprocess.run(["bash", str(ROOT / script), *args],
                              env=self.env, capture_output=True, text=True)

    def test_actions_on_booking_and_managed_hosts(self):
        for name, machines in [(self.local, ["example-managed"]),
                               ("example-booking", [self.local])]:
            self.inventory(name, machines)
            for action in ["list", "add", "share", "cancel"]:
                with self.subTest(host=name, action=action):
                    args = ["--server", "incus-01", "--shared", "a user", "--date", ""]
                    result = self.run_command(*args, script=f"cmd/booking/{action}.sh")
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, "\n".join(["odev booking " + action, *args]) + "\n")

    def test_unlisted_and_empty_inventory(self):
        for data in [{"servers": []}, {"servers": [{"name": "other-booking",
                      "managed_servers": [], "maximum_duration_hours": 5}]}]:
            self.db.write_text(yaml.safe_dump(data))
            for script, args in [("cmd/booking.sh", ["list"]),
                                 ("cmd/booking/add.sh", [])]:
                result = self.run_command(*args, script=script)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "Command not available: odev booking\n")

    def test_invalid_or_missing_inventory(self):
        for content in [None, "servers: [", "servers: invalid"]:
            if content is not None:
                self.db.write_text(content)
            result = self.run_command("add")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("ERROR:", result.stderr)
            self.assertNotIn("odev booking add", result.stdout)

    def test_help_and_unknown_action(self):
        self.inventory(self.local, [])
        self.assertIn("USAGE:", self.run_command().stdout)
        self.assertEqual(self.run_command("--help").returncode, 0)
        for action in ["list", "add", "share", "cancel"]:
            resolved = subprocess.run(
                ["bash", str(ROOT / "src/workflow_command_path.sh"), str(ROOT), "booking", action],
                env=self.env, capture_output=True, text=True)
            self.assertEqual(resolved.returncode, 0)
            self.assertEqual(resolved.stdout.strip(), str(ROOT / f"cmd/booking/{action}.sh"))
        unknown = subprocess.run(
            ["bash", str(ROOT / "src/workflow_command_path.sh"), str(ROOT), "booking", "new"],
            env=self.env, capture_output=True, text=True)
        self.assertNotEqual(unknown.returncode, 0)

    def test_flag_specs_and_placeholder_arguments(self):
        self.inventory(self.local, [])
        expected = {
            "list": ["all", "server", "date"],
            "add": ["server", "date", "start", "duration", "shared"],
            "share": ["server", "user", "booking-id"],
            "cancel": ["server", "booking-id"],
        }
        # Isolate booking definitions from unrelated workflow discovery.
        spec = Path(self.temp.name) / "booking_spec.sh"
        source = (ROOT / "src/cmd_spec.sh").read_text()
        spec.write_text(source.split("# booking (", 1)[1].split("# build", 1)[0].split("\n", 1)[1])
        for action, names in expected.items():
            with self.subTest(action=action):
                flags = subprocess.run(
                    ["bash", str(ROOT / "src/cmd_flags_read.sh"), str(ROOT),
                     "BOOKING_" + action.upper(), "--db", str(spec)],
                    env={**self.env, "TERM": "xterm"}, capture_output=True, text=True)
                self.assertEqual(flags.returncode, 0, flags.stderr)
                self.assertEqual([line.split(",")[0] for line in flags.stdout.splitlines()], names)
                args = []
                for name in names:
                    args.append("--" + name)
                    if name != "all":
                        args.append("test-value")
                result = self.run_command(*args, script=f"cmd/booking/{action}.sh")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "\n".join(["odev booking " + action, *args]) + "\n")


if __name__ == "__main__":
    unittest.main()
