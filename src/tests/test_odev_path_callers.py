"""Check every shell consumer and real metadata discovery with an isolated config."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
CALL = re.compile(r'^\s*(\w+)="\$\(python3 "\$ODEV_PATH/src/odev_path.py" (models|projects|workflows|playbooks)\)"')


def scripts():
    paths = [ROOT / "odev.sh", ROOT / "odev_login.sh", ROOT / "odev_completion.sh"]
    paths += list((ROOT / "cmd").rglob("*.sh"))
    paths += list((ROOT / "src").glob("*.sh"))
    paths += list((ROOT / "templates/workflows").glob("*.sh"))
    return sorted({path.resolve() for path in paths
                   if not path.resolve().is_relative_to(ROOT / "submodules")})


class PathCallerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="odev-callers-", dir="/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.data = self.directory / "user data with spaces"
        self.config = self.directory / "odev_path.yml"
        self.config.write_text(yaml.safe_dump({"data_path": str(self.data)}))
        binary = self.directory / "bin"
        binary.mkdir()
        python = binary / "python3"
        python.write_text(f"#!{sys.executable}\n" +
                         "import os, sys\nargs = sys.argv[1:]\n" +
                         "if args and args[0].endswith('/src/odev_path.py'): args += ['--db', os.environ['TEST_ODEV_PATH_CONFIG']]\n" +
                         "os.execv(sys.executable, [sys.executable, *args])\n")
        python.chmod(0o755)
        self.env = {**os.environ, "ODEV_PATH": str(ROOT), "TERM": "xterm",
                    "PYTHONDONTWRITEBYTECODE": "1", "TEST_ODEV_PATH_CONFIG": str(self.config),
                    "PATH": str(binary) + os.pathsep + os.environ["PATH"]}

    def test_no_shell_reader_uses_retired_vars_entries(self):
        obsolete = re.compile(r"read_yml\.py.*\bpaths\s+(models|projects|workflows|playbooks)\b")
        count = 0
        for path in scripts():
            for line in path.read_text().splitlines():
                self.assertIsNone(obsolete.search(line), f"{path}: {line}")
                if CALL.match(line):
                    count += 1
                    self.assertNotIn("eval", line)
        self.assertGreaterEqual(count, 32)

    def test_all_actual_assignments_resolve_spaces_and_stop_on_config_errors(self):
        count = 0
        for path in scripts():
            assignments = [(line, CALL.match(line)) for line in path.read_text().splitlines() if CALL.match(line)]
            if not assignments:
                continue
            snippet = self.directory / "assignments.sh"
            snippet.write_text("\n".join(line for line, _ in assignments) + "\n")
            prints = "\n".join(f'printf "%s\\n" "${{{match.group(1)}}}"' for _, match in assignments)
            command = ['bash', '-c', 'source "$1" || exit 1\n' + prints, 'test', str(snippet)]
            result = subprocess.run(command, env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, f"{path}: {result.stderr}")
            self.assertEqual(result.stdout.splitlines(), [str(self.data / match.group(2)) for _, match in assignments])
            self.assertFalse(self.data.exists())
            self.config.unlink()
            result = subprocess.run(command, env=self.env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, str(path))
            self.assertEqual(result.stdout, "", str(path))
            self.assertIn("Cannot resolve odev data path", result.stderr)
            self.config.write_text(yaml.safe_dump({"data_path": str(self.data)}))
            count += len(assignments)
        self.assertGreaterEqual(count, 32)

    def test_personal_workflow_metadata_discovery_uses_new_location(self):
        workflow = self.data / "workflows/example"
        workflow.mkdir(parents=True)
        (workflow / "cmd_spec.sh").write_text("USER_WORKFLOW_FOUND=yes\n")
        command = ["bash", "-c", 'KEY=NEW\nsource "$ODEV_PATH/src/cmd_spec.sh" || exit 1\nprintf "%s\\n" "$WORKFLOWS_USER_PATH" "$PLAYBOOKS_USER_PATH" "$USER_WORKFLOW_FOUND"']
        result = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [str(self.data / "workflows"), str(self.data / "playbooks"), "yes"])

    def test_completion_failure_does_not_exit_the_interactive_shell(self):
        self.config.unlink()
        command = ["bash", "-c", 'source "$ODEV_PATH/odev_completion.sh"\n_odev_source_flags "$ODEV_PATH" new\nprintf "shell-alive\\n"']
        result = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "shell-alive\n")


if __name__ == "__main__":
    unittest.main()
