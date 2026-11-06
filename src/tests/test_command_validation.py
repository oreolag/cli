"""Early-exit behavior with fixture inventories, fake actions and real terminal dialogs.

Run on Ubuntu/Bash 4+: python3 -m unittest discover -s src/tests.
No remote service, host configuration or repository mutation is used.
"""
import errno
import os
from pathlib import Path
import pty
import select
import signal
import socket
import subprocess
import sys
import tempfile
import time
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
BASH_MAJOR = int(subprocess.check_output(
    ["bash", "-c", "echo ${BASH_VERSINFO[0]}"], text=True))


@unittest.skipIf(BASH_MAJOR < 4, "odev requires Bash 4+")
class CommandValidationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="odev-validation-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "src").mkdir()
        for path in (ROOT / "src").iterdir():
            if path.is_file():
                (self.root / "src" / path.name).symlink_to(path)
        for name, body in [("is_member.sh", "echo 1"), ("gh_auth_status.sh", "echo 1")]:
            (self.root / "src" / name).unlink()
            self.script(self.root / "src" / name, body)
        (self.root / "templates").symlink_to(ROOT / "templates")
        (self.root / "cmd").symlink_to(ROOT / "cmd")
        (self.root / "booking").mkdir()
        (self.root / "booking/client.py").write_text(
            'import os, pathlib\n'
            'with pathlib.Path(os.environ["ACTION_LOG"]).open("a") as stream: stream.write("booking\\n")\n'
            'print("BOOKING EXECUTED")\n')
        for name in ("playbooks", "workflows", "mgmt", "bin"):
            (self.root / name).mkdir()
        (self.root / "playbooks/demo.yml").write_text("---\n")
        (self.root / "workflows/demo").mkdir()
        (self.root / "workflows/demo/cmd_spec.sh").write_text(":\n")
        self.cmdb = self.root / "host.yml"
        self.cmdb.write_text(yaml.safe_dump({"devices": {
            "cpu": {"numa": [{"id": 0, "endata": [0], "accel": [0]}]},
            "endata": [{"id": 0, "ports": [{"id": 0, "name": "eth-test", "ip_address": "192.0.2.1", "mac": "aa:bb:cc:dd:ee:ff"}]}],
            "accel": [{"id": 0, "ports": [{"id": 0, "name": "eth-test"}]}]}}))
        self.inventory = self.root / "booking.yml"
        self.inventory.write_text(yaml.safe_dump({"timezone": "UTC", "servers": [{
            "name": socket.gethostname().split(".")[0], "id": "01",
            "managed_servers": ["incus-01"], "maximum_duration_hours": 5}]}))
        (self.root / "vars.yml").write_text(yaml.safe_dump({"paths": {
            "booking": str(self.inventory), "cmdb": str(self.root), "tmp": str(self.root),
            "workflows": str(self.root / "workflows"), "playbooks": str(self.root / "playbooks"),
            "mgmt": str(self.root / "mgmt")}}))
        self.marker = self.root / "actions"
        self.script(self.root / "bin/ifconfig", 'echo ifconfig >> "$ACTION_LOG"\necho "inet 192.0.2.1"\necho "ether aa:bb:cc:dd:ee:ff"')
        self.script(self.root / "mgmt/ansible-play.sh", '[[ -f "$1" ]] || exit 81\necho "ansible $*" >> "$ACTION_LOG"\necho EXECUTED')
        self.script(self.root / "bin/id", '''case "$1" in
  -un) echo tester ;;
  -nG) if [[ "$3" == tester ]]; then echo "users odev-users"; else exit 1; fi ;;
  *) exit 1 ;;
esac''')
        self.script(self.root / "bin/gh", '''if [[ "$1" == api ]]; then
  printf '%s' "${UPSTREAM_NAMES:-}"
else
  echo UNEXPECTED-GH-ACTION >> "$ACTION_LOG"
  exit 80
fi''')
        for name in ("git", "sudo"):
            self.script(self.root / "bin" / name, 'echo UNEXPECTED-ACTION >> "$ACTION_LOG"\nexit 80')
        # Production targets GNU date on Ubuntu; emulate only -d on macOS.
        if sys.platform == "darwin":
            clock = self.root / "bin/date"
            clock.write_text(f"#!{sys.executable}\n" + "import datetime, os, subprocess, sys\nfrom zoneinfo import ZoneInfo\nargs = sys.argv[1:]\nif args and args[0] == '-d':\n    try:\n        fmt = '%Y-%m-%d %H:%M' if ' ' in args[1] else '%Y-%m-%d'\n        value = datetime.datetime.strptime(args[1], fmt).replace(tzinfo=ZoneInfo(os.environ.get('TZ', 'UTC')))\n        print(int(value.timestamp()) if args[2] == '+%s' else value.strftime(args[2][1:]))\n    except (ValueError, IndexError):\n        sys.exit(1)\nelse:\n    sys.exit(subprocess.call(['/bin/date', *args]))\n")
            clock.chmod(0o755)
        self.env = {**os.environ, "ODEV_PATH": str(self.root), "CMDB_DB_FILE": str(self.cmdb),
                    "BOOKING_DB_FILE": str(self.inventory), "TERM": "xterm", "USER": "tester",
                    "ACTION_LOG": str(self.marker), "PYTHONDONTWRITEBYTECODE": "1",
                    "PATH": str(self.root / "bin") + os.pathsep + os.environ["PATH"]}

    def script(self, path, body):
        path.write_text("#!/usr/bin/env bash\n" + body + "\n")
        path.chmod(0o755)

    def command(self, name, *args):
        return ["bash", str(ROOT / "cmd" / (name + ".sh")), *args]

    def run_command(self, name, *args):
        return subprocess.run(self.command(name, *args), env=self.env,
                              capture_output=True, text=True, start_new_session=True, timeout=15)

    def dialog(self, name, args, answers=()):
        """Drive /dev/tty, asserting the actual sequence of questions."""
        pid, fd = pty.fork()
        if pid == 0:
            os.execvpe("bash", self.command(name, *args), self.env)
        output = b""
        remaining = list(answers)
        deadline = time.monotonic() + 15
        status = None
        try:
            while time.monotonic() < deadline:
                if select.select([fd], [], [], 0.1)[0]:
                    try:
                        data = os.read(fd, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        break
                    if not data:
                        break
                    output += data
                    if remaining and remaining[0][0].encode() in output:
                        _, answer = remaining.pop(0)
                        os.write(fd, answer.encode() + b"\n")
                ended, status = os.waitpid(pid, os.WNOHANG)
                if ended:
                    # Read buffered output after the process has exited.
                    while select.select([fd], [], [], 0)[0]:
                        try:
                            data = os.read(fd, 65536)
                        except OSError:
                            break
                        if not data:
                            break
                        output += data
                    break
            else:
                self.fail("Dialog timed out: " + output.decode(errors="replace"))
        finally:
            os.close(fd)
            try:
                ended, final = os.waitpid(pid, os.WNOHANG)
                if not ended:
                    os.kill(pid, signal.SIGKILL)
                    _, final = os.waitpid(pid, 0)
                status = final
            except ChildProcessError:
                pass
        self.assertFalse(remaining, output.decode(errors="replace"))
        return os.waitstatus_to_exitcode(status), output.decode(errors="replace")

    def assert_early(self, name, args, error, absent):
        status, output = self.dialog(name, args)
        self.assertNotEqual(status, 0, output)
        self.assertIn(error, output)
        for question in absent:
            self.assertNotIn(question, output)
        self.assertFalse(self.marker.exists(), output)

    def test_invalid_supplied_values_never_open_dialog_or_act(self):
        cases = [
            ("get/ip", ["--numa", "1"], "Invalid numa: 1", ["device:"]),
            ("get/mac", ["--numa", "1"], "Invalid numa: 1", ["device:"]),
            ("get/ip", ["--device", "99"], "Invalid device: 99", ["numa:"]),
            ("get/mac", ["--device", "0", "--port", "9"], "Invalid port: 9", ["numa:"]),
            ("set/mtu", ["--interface", "99"], "Invalid interface: 99", ["value ("]),
            ("set/mtu", ["--interface", "0", "--port", "9"], "Invalid port: 9", ["value ("]),
            ("booking/add", ["--server", "incus-05"], "Invalid server: incus-05", ["start ["]),
            ("booking/add", ["--duration", "6"], "Invalid duration: 6", ["server:", "start ["]),
            ("booking/add", ["--date", "2027-02-30"], "Invalid booking date", ["server:", "start ["]),
            ("booking/add", ["--shared", "missing"], "Invalid user: missing", ["server:", "start ["]),
            ("booking/share", ["--add", "missing"], "Invalid user: missing", ["booking:"]),
            ("booking/share", ["--add", "tester", "--remove", "tester"], "Invalid flags", ["booking:"]),
            ("booking/list", ["--history", "bad"], "Invalid booking date", []),
            ("run/playbook", ["--inventory", str(self.root / "missing")], "Inventory does not exist", ["name:"]),
            ("run/playbook", ["--name", "missing"], "Playbook does not exist", []),
            ("delete/playbook", ["--name", "missing"], "Playbook does not exist", []),
            ("delete/workflow", ["--name", "missing"], "Workflow does not exist", []),
            ("new/workflow", ["--template", "missing"], "Template does not exist", ["name:"]),
            ("new/workflow", ["--name", "../bad"], "Invalid workflow name", []),
            ("new/playbook", ["--name", "../bad"], "Invalid playbook name", []),
            ("new/playbook", ["--name", "demo"], "Playbook already exists", []),
        ]
        for name, args, error, absent in cases:
            with self.subTest(name=name, args=args):
                self.assert_early(name, args, error, absent)

    def test_delete_playbook_keeps_inline_protections(self):
        self.assert_early("delete/playbook", ["--name", "../bad"], "Invalid playbook name", [])
        community = self.root / "submodules/playbooks"
        community.mkdir(parents=True)
        playbook = community / "demo.yml"
        playbook.write_text("---\n")
        self.assert_early("delete/playbook", ["--name", "demo"], "Playbook cannot be deleted: demo", [])
        playbook.unlink()
        playbook.symlink_to(community / "missing.yml")
        self.assert_early("delete/playbook", ["--name", "demo"], "Playbook cannot be deleted: demo", [])

    def test_invalid_answer_stops_before_next_question(self):
        status, output = self.dialog("get/ip", [], [("numa: ", "1")])
        self.assertNotEqual(status, 0, output)
        self.assertIn("Invalid numa: 1", output)
        self.assertNotIn("device:", output)
        self.assertFalse(self.marker.exists())

    def test_valid_partial_request_prompts_and_executes(self):
        status, output = self.dialog("get/ip", ["--numa", "0"], [("device: ", "0")])
        self.assertEqual(status, 0, output)
        self.assertIn("192.0.2.1", output)
        self.assertNotIn("numa:", output)
        self.assertEqual(self.marker.read_text(), "ifconfig\n")

    def test_booking_answers_are_checked_before_advancing(self):
        status, output = self.dialog("booking/add", ["--date", "2099-01-01"], [("server: ", "incus-05")])
        self.assertNotEqual(status, 0, output)
        self.assertIn("Invalid server: incus-05", output)
        self.assertNotIn("start [", output)
        self.assertFalse(self.marker.exists())

    def test_valid_booking_partial_request(self):
        status, output = self.dialog("booking/add", ["--date", "2099-01-01", "--server", "incus-01"],
                                     [("start [", "14:00")])
        self.assertEqual(status, 0, output)
        self.assertIn("BOOKING EXECUTED", output)

    def test_dependency_becomes_known_after_answer(self):
        # Device 1 exists, but is attached to a different NUMA selection.
        data = yaml.safe_load(self.cmdb.read_text())
        data["devices"]["endata"].append({"id": 1, "ports": [{"id": 0, "name": "eth-other"}]})
        self.cmdb.write_text(yaml.safe_dump(data))
        status, output = self.dialog("get/ip", ["--device", "1"], [("numa: ", "0")])
        self.assertNotEqual(status, 0, output)
        self.assertIn("Invalid device: 1", output)
        self.assertFalse(self.marker.exists())

    def test_complete_valid_commands_need_no_terminal(self):
        for name, args, expected in [
            ("get/ip", ["--numa", "0", "--device", "0"], "192.0.2.1"),
            ("get/mac", ["--numa", "0", "--device", "0"], "aa:bb:cc:dd:ee:ff"),
            ("set/mtu", ["--interface", "0", "--value", "1500"], "EXECUTED"),
            ("run/playbook", ["--name", "demo"], "EXECUTED"),
            ("booking/add", ["--server", "incus-01", "--date", "2099-01-01", "--start", "14:00"], "BOOKING EXECUTED"),
            ("booking/list", ["--history", "2099-01-01"], "BOOKING EXECUTED"),
            ("booking/share", ["--booking", "391", "--add", "tester"], "tester\n391\n-"),
            ("booking/cancel", ["--booking", "391"], "391"),
        ]:
            with self.subTest(name=name):
                result = self.run_command(name, *args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected, result.stdout)
                self.assertNotIn("not interactive", result.stderr)

    def test_booking_share_asks_only_for_selected_action(self):
        status, output = self.dialog("booking/share", ["--remove", "tester"], [("booking: ", "391")])
        self.assertEqual(status, 0, output)
        self.assertNotIn("add:", output)
        self.assertNotIn("remove:", output)

    def test_parser_rejects_missing_values_before_dialog(self):
        for args in (["--numa"], ["--numa", ""], ["--numa", "--device", "0"]):
            with self.subTest(args=args):
                self.assert_early("get/ip", args, "Missing value for --numa", ["device:", "numa:"])
        self.assert_early("get/ip", ["--numa", "-1"], "Invalid numa: -1", ["device:"])

    def test_upstream_duplicate_is_read_only(self):
        self.env["UPSTREAM_NAMES"] = "taken\n"
        self.assert_early("new/workflow", ["--name", "taken"], "Workflow already exists: taken", [])
        self.assertFalse((self.root / "workflows/taken").exists())
