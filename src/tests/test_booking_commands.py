"""Run with PyYAML installed: python3 -m unittest discover -s src/tests."""
import os
from pathlib import Path
import socket
import shutil
import subprocess
import sys
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
BASH_MAJOR = int(subprocess.check_output(["bash", "-c", "echo ${BASH_VERSINFO[0]}"], text=True))


class BookingCommandsTest(unittest.TestCase):
    def test_description_batch_and_lazy_booking_metadata(self):
        checkout = Path(self.temp.name) / "metadata"
        (checkout / "src").mkdir(parents=True)
        workflow = checkout / "users/workflows/example"
        workflow.mkdir(parents=True)
        (workflow / "cmd_spec.sh").write_text(":\n")
        source = (ROOT / "src/cmd_spec.sh").read_text()
        (checkout / "src/cmd_spec.sh").write_text(
            'echo source >> "$ODEV_PATH/spec_reads"\n' + source)
        for name in ["cmd_description_read.sh", "cmd_flags_read.sh", "cmd_mandatory_flags_read.sh"]:
            (checkout / "src" / name).symlink_to(ROOT / "src" / name)
        scripts = {
            "read_yml.py": 'echo "$ODEV_PATH/users/workflows"',
            "booking_timezone.sh": 'echo read >> "$ODEV_PATH/timezone_reads"\necho Europe/Madrid',
        }
        for name, body in scripts.items():
            helper = checkout / "src" / name
            helper.write_text("#!/bin/bash\n" + body + "\n")
            helper.chmod(0o755)
        env = {**self.env, "ODEV_PATH": str(checkout), "BOOKING_TIMEZONE": ""}
        def metadata(script, key):
            result = subprocess.run(["bash", str(checkout / "src" / script), str(checkout), key],
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout
        batch = metadata("cmd_description_read.sh", "ALL")
        self.assertEqual(len(batch.splitlines()), 11)
        self.assertEqual((checkout / "spec_reads").read_text().splitlines(), ["source"])
        self.assertFalse((checkout / "timezone_reads").exists())
        names = dict(line.split("=", 1) for line in batch.splitlines())
        for key, name in [("BUILD", "build"), ("NEW", "new"), ("GH", "gh_description")]:
            self.assertEqual(metadata("cmd_description_read.sh", key).strip(), names[name])
        self.assertFalse((checkout / "timezone_reads").exists())
        self.assertIn("Europe/Madrid", metadata("cmd_description_read.sh", "BOOKING_ADD"))
        self.assertIn("start,,", metadata("cmd_flags_read.sh", "BOOKING_ADD"))
        self.assertEqual(metadata("cmd_mandatory_flags_read.sh", "BOOKING_ADD").strip(), "server,start")

    def test_shared_booking_timezone(self):
        self.db.write_text("timezone: Europe/Madrid\nservers: []\n")
        result = subprocess.run(["bash", str(ROOT / "src/booking_timezone.sh"), str(ROOT)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "Europe/Madrid")
        self.db.write_text("timezone: invalid/timezone\nservers: []\n")
        result = subprocess.run(["bash", str(ROOT / "src/booking_timezone.sh"), str(ROOT)],
                                env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid booking timezone", result.stderr)
        self.db.write_text("servers: []\n")
        result = subprocess.run(["bash", str(ROOT / "src/booking_timezone.sh"), str(ROOT)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.stdout.strip(), "UTC")

    def test_booking_defaults_use_inventory_timezone(self):
        self.db.write_text("timezone: Europe/Madrid\nservers: []\n")
        # Fix the instant at 11:42 UTC; Madrid's booking default must be 13:45.
        clock = Path(self.temp.name) / "date"
        clock.write_text(f"#!{sys.executable}\n" + '''import datetime, os, sys
from zoneinfo import ZoneInfo
now = datetime.datetime(2026, 10, 20, 11, 42, tzinfo=datetime.timezone.utc)
print(now.astimezone(ZoneInfo(os.environ.get('TZ', 'UTC'))).strftime(sys.argv[1][1:]))
''')
        clock.chmod(0o755)
        source = (ROOT / "src/cmd_spec.sh").read_text()
        spec = Path(self.temp.name) / "spec.sh"
        spec.write_text(source.split("# booking (", 1)[1].split("# build", 1)[0].split("\n", 1)[1])
        result = subprocess.run(["bash", "-c", 'source "$1"; printf "%s\\n" "${BOOKING_ADD_FLAGS[@]}"', "test", str(spec)],
            env={**self.env, "TZ": "UTC", "BOOKING_TIMEZONE": "",
                 "PATH": self.temp.name + os.pathsep + os.environ["PATH"]},
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("start,,Start time (HH:MM),-,13:45", result.stdout)
        self.assertIn("date,d,Booking date (YYYY-MM-DD),-,2026-10-20", result.stdout)

    def test_booking_add_validates_supplied_start_before_prompt(self):
        # Exercise the command's actual validation blocks with a fixed clock.
        source = (ROOT / "cmd/booking/add.sh").read_text()
        validation = source.split("# validate supplied or completed start values\n", 1)[1].split("# parse flags", 1)[0]
        early = source.split("# validate supplied input before asking for missing fields\n", 1)[1].split("# run interactive prompt", 1)[0]
        clock = Path(self.temp.name) / "date"
        clock.write_text(f"#!{sys.executable}\n" + '''import datetime, os, sys
from zoneinfo import ZoneInfo
args = sys.argv[1:]
if args == ['+%F']:
    print('2026-10-20')
elif args == ['+%s']:
    print(int(datetime.datetime(2026, 10, 20, 12, 0, tzinfo=datetime.timezone.utc).timestamp()))
else:
    try:
        value = datetime.datetime.strptime(args[1], '%Y-%m-%d %H:%M')
        print(int(value.replace(tzinfo=ZoneInfo(os.environ['TZ'])).timestamp()))
    except ValueError:
        sys.exit(1)
''')
        clock.chmod(0o755)
        cases = [
            ("start=11:20", "Invalid start time: 2026-10-20 11:20"),
            ("start=11.20", "Invalid value for --start:"),
            ("start=6:55", "Invalid value for --start:"),
            ("start=12:00", "Invalid start time: 2026-10-20 12:00"),
            ("start=13:20", None),
            ("date=2026-10-21\nstart=11:20", None),
            ("server=incus-01", None),
        ]
        timezone_cases = [("UTC", values, error) for values, error in cases]
        timezone_cases += [
            ("Europe/Madrid", "start=13:20", "Invalid start time: 2026-10-20 13:20"),
            ("Europe/Madrid", "start=14:20", None),
        ]
        for timezone, values, error in timezone_cases:
            with self.subTest(values=values):
                result = subprocess.run(
                    ["bash", "-c", validation + '\nparsed_flags="$1"\n' + early + '\necho DIALOG\n', "test", values],
                    env={**self.env, "TZ": "UTC", "BOOKING_TIMEZONE": timezone,
                         "PATH": self.temp.name + os.pathsep + os.environ["PATH"]},
                    capture_output=True, text=True)
                if error:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(error, result.stderr)
                    self.assertNotIn("DIALOG", result.stdout)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("DIALOG", result.stdout)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Path(self.temp.name) / "booking.yml"
        self.local = socket.gethostname().split(".")[0]
        self.env = {**os.environ, "BOOKING_DB_FILE": str(self.db), "ODEV_PATH": str(ROOT), "TERM": "xterm"}

    def inventory(self, name, machines):
        self.db.write_text(yaml.safe_dump({"servers": [{
            "name": name, "managed_servers": machines,
            "maximum_duration_hours": 5, "terminate_jobs": True,
        }]}))

    def run_command(self, *args, script="cmd/booking.sh"):
        return subprocess.run(["bash", str(ROOT / script), *args],
                              env=self.env, capture_output=True, text=True)

    @unittest.skipIf(BASH_MAJOR < 4, "Parsing and prompts require Bash 4+ (odev targets Ubuntu)")
    def test_actions_on_booking_and_managed_hosts(self):
        cases = {
            "list": (["--all", "1", "--date", "2026-10-15", "--server", "incus-01"],
                     ["1", "2026-10-15", "incus-01"]),
            "add": (["--date", "2026-10-15", "--duration", "2", "--server", "incus-01",
                     "--shared", "javier", "--start", "18:12"],
                    ["2026-10-15", "2", "incus-01", "javier", "18:12"]),
            "share": (["--booking", "391", "--users", "javier,quico"],
                      ["391", "javier,quico"]),
            "cancel": (["--booking", "391"], ["391"]),
        }
        for name, machines in [(self.local, ["example-managed"]),
                               ("example-booking", [self.local])]:
            self.inventory(name, machines)
            for action in ["list", "add", "share", "cancel"]:
                with self.subTest(host=name, action=action):
                    args, values = cases[action]
                    result = self.run_command(*args, script=f"cmd/booking/{action}.sh")
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, "\n".join(values) + "\n")

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

    def test_flag_specs_and_mandatory_flags(self):
        self.inventory(self.local, [])
        expected = {
            "list": ["all", "server", "date"],
            "add": ["server", "date", "start", "duration", "shared"],
            "share": ["booking", "users"],
            "cancel": ["booking"],
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
                self.assertCountEqual([line.split(",")[0] for line in flags.stdout.splitlines()], names)
                mandatory = subprocess.run(
                    ["bash", str(ROOT / "src/cmd_mandatory_flags_read.sh"), str(ROOT),
                     "BOOKING_" + action.upper(), "--db", str(spec)],
                    env=self.env, capture_output=True, text=True)
                self.assertEqual(mandatory.returncode, 0, mandatory.stderr)
                expected_mandatory = {"list": "", "add": "server,start",
                                      "share": "booking,users", "cancel": "booking"}
                self.assertEqual(mandatory.stdout.strip(), expected_mandatory[action])

    def test_startup_survives_missing_booking_configuration(self):
        checkout = Path(self.temp.name) / "cli"
        (checkout / "src").mkdir(parents=True)
        shutil.copy(ROOT / "odev.sh", checkout / "odev.sh")
        for name in ["is_server.sh", "read_yml.py", "booking_is_server.py", "cmdb_get.py"]:
            (checkout / "src" / name).symlink_to(ROOT / "src" / name)
        descriptions = "\n".join(name + "=Description" for name in
            ["build", "get", "ifconfig", "new", "program", "run", "set", "update", "validate", "examine", "gh_description"])
        for name, output in [("is_member.sh", "1"), ("required_tools_print.sh", "0"),
                             ("cmd_description_read.sh", descriptions)]:
            helper = checkout / "src" / name
            helper.write_text('#!/bin/bash\nprintf "%s\\n" "' + output + '"\n')
            helper.chmod(0o755)
        host = checkout / "host.yml"
        host.write_text("devices: {}\n")
        for paths in [{"cmdb": "/opt"}, {"cmdb": "/opt", "booking": str(self.db)}]:
            (checkout / "vars.yml").write_text(yaml.safe_dump({"paths": paths}))
            result = subprocess.run(["bash", str(checkout / "odev.sh"), "--help"],
                env={**self.env, "BOOKING_DB_FILE": "", "CMDB_DB_FILE": str(host),
                     "TERM": "xterm", "USER": "test-user"}, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("CORE COMMANDS", result.stdout)
            self.assertNotIn("Is a directory", result.stderr)

    def test_legacy_vars_use_default_inventory_path(self):
        checkout = Path(self.temp.name) / "legacy"
        (checkout / "src").mkdir(parents=True)
        (checkout / "src/read_yml.py").symlink_to(ROOT / "src/read_yml.py")
        (checkout / "vars.yml").write_text("paths: {}\n")
        reader = checkout / "src/booking_is_server.py"
        reader.write_text('import sys\nassert sys.argv[sys.argv.index("--db") + 1] == "/opt/booking.yml"\nprint(1)\n')
        for script, args in [("src/is_server.sh", [str(checkout), "booking"]),
                             ("src/booking_available.sh", [str(checkout)])]:
            result = subprocess.run(["bash", str(ROOT / script), *args],
                env={**self.env, "BOOKING_DB_FILE": ""}, capture_output=True, text=True)
            if script.endswith("is_server.sh"):
                self.assertEqual(result.stdout.strip(), "1")
            else:
                self.assertNotIn("Is a directory", result.stderr)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
