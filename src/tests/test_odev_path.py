"""User-data resolution tests; no mounts, account changes or persistent files."""
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import yaml


SCRIPT = Path(__file__).resolve().parents[1] / "odev_path.py"
spec = importlib.util.spec_from_file_location("odev_path", SCRIPT)
odev_path = importlib.util.module_from_spec(spec)
spec.loader.exec_module(odev_path)


class OdevPathTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="odev-path-", dir="/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.config = Path(self.temporary.name) / "odev_path.yml"
        self.account = SimpleNamespace(pw_name="alice", pw_dir="/home/alice")
        self.config.write_text('data_path: "${HOME}/odev"\n')
        self.enterContext(patch.object(odev_path.os, "geteuid", return_value=1001))
        self.lookup = self.enterContext(patch.object(odev_path.pwd, "getpwuid", return_value=self.account))

    def configure(self, value):
        self.config.write_text(yaml.safe_dump({"data_path": value}))

    def test_default_config_location(self):
        self.assertEqual(odev_path.CONFIG_PATH, Path("/opt/odev_path.yml"))

    def test_root_and_all_four_subdirectories(self):
        self.assertEqual(odev_path.resolve_path(config_path=self.config), Path("/home/alice/odev"))
        for name in ("models", "projects", "workflows", "playbooks"):
            self.assertEqual(odev_path.resolve_path(name, self.config), Path("/home/alice/odev") / name)

    def test_shared_root(self):
        self.configure("/scratch/${USER}/odev")
        self.assertEqual(odev_path.resolve_path("projects", self.config), Path("/scratch/alice/odev/projects"))

    def test_sudo_uses_original_account_not_root_environment(self):
        with patch.object(odev_path.os, "geteuid", return_value=0), patch.dict(os.environ, {"SUDO_UID": "1001", "HOME": "/root", "USER": "root"}):
            self.assertEqual(odev_path.resolve_path("workflows", self.config), Path("/home/alice/odev/workflows"))
            self.lookup.assert_called_with(1001)

    def test_regular_user_ignores_sudo_and_home_environment(self):
        with patch.dict(os.environ, {"SUDO_UID": "0", "HOME": "/wrong", "USER": "wrong"}):
            self.assertEqual(odev_path.resolve_path("models", self.config), Path("/home/alice/odev/models"))
            self.lookup.assert_called_with(1001)

    def test_root_without_sudo_uses_root_account(self):
        with patch.object(odev_path.os, "geteuid", return_value=0), patch.dict(os.environ, {}, clear=True):
            self.lookup.return_value = SimpleNamespace(pw_name="root", pw_dir="/root")
            self.assertEqual(odev_path.resolve_path(config_path=self.config), Path("/root/odev"))
            self.lookup.assert_called_with(0)

    def test_invalid_sudo_uid_does_not_fall_back_to_root(self):
        with patch.object(odev_path.os, "geteuid", return_value=0), patch.dict(os.environ, {"SUDO_UID": "wrong"}):
            with self.assertRaisesRegex(ValueError, "Invalid SUDO_UID"):
                odev_path.resolve_path(config_path=self.config)

    def test_unknown_account(self):
        self.lookup.side_effect = KeyError(1001)
        with self.assertRaisesRegex(ValueError, "No account found"):
            odev_path.resolve_path(config_path=self.config)

    def test_missing_config_has_no_silent_fallback(self):
        self.config.unlink()
        with self.assertRaises(FileNotFoundError):
            odev_path.resolve_path(config_path=self.config)

    def test_invalid_roots(self):
        for value in (None, [], {}, 1, True, "", "  ", "relative/odev", "~other/odev", "/scratch/${UNKNOWN}", "/scratch/$USER_SUFFIX", "/scratch/one\ntwo"):
            with self.subTest(value=value):
                self.configure(value)
                with self.assertRaises(ValueError):
                    odev_path.resolve_path(config_path=self.config)

    def test_invalid_yaml(self):
        self.config.write_text("data_path: [")
        with self.assertRaises(yaml.YAMLError):
            odev_path.resolve_path(config_path=self.config)

    def test_shell_code_is_never_evaluated(self):
        marker = Path(self.temporary.name) / "executed"
        self.configure(f"/scratch/$(touch {marker})")
        with self.assertRaises(ValueError):
            odev_path.resolve_path(config_path=self.config)
        self.configure(f"/scratch/`touch {marker}`")
        odev_path.resolve_path(config_path=self.config)
        self.assertFalse(marker.exists())

    def test_spaces_and_literal_unbraced_variables(self):
        self.account.pw_dir = "/home/alice with spaces"
        self.configure("$HOME/odev/$USER")
        self.assertEqual(odev_path.resolve_path(config_path=self.config), Path("/home/alice with spaces/odev/alice"))

    def test_tilde_home(self):
        self.configure("~/odev")
        self.assertEqual(odev_path.resolve_path(config_path=self.config), Path("/home/alice/odev"))

    def test_no_directories_are_created(self):
        destination = Path(self.temporary.name) / "not-created"
        self.configure(str(destination))
        self.assertEqual(odev_path.resolve_path("models", self.config), destination / "models")
        self.assertFalse(destination.exists())

    def test_directory_traversal_is_not_a_supported_category(self):
        with self.assertRaises(ValueError):
            odev_path.resolve_path("../elsewhere", self.config)

    def test_command_outputs_path_and_returns_errors_without_traceback(self):
        output, errors = io.StringIO(), io.StringIO()
        with redirect_stdout(output), redirect_stderr(errors):
            code = odev_path.main(["workflows", "--db", str(self.config)])
        self.assertEqual(code, 0)
        self.assertEqual(output.getvalue(), "/home/alice/odev/workflows\n")
        self.assertEqual(errors.getvalue(), "")
        self.config.unlink()
        with redirect_stderr(errors):
            code = odev_path.main(["--db", str(self.config)])
        self.assertEqual(code, 1)
        self.assertIn("Cannot resolve odev data path:", errors.getvalue())
        self.assertNotIn("Traceback", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
