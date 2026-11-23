"""The shell and Python interfaces share wording and preserve supplied values."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest


HELPER = Path(__file__).resolve().parents[1] / "odev_messages.py"
spec = importlib.util.spec_from_file_location("odev_messages", HELPER)
messages = importlib.util.module_from_spec(spec)
spec.loader.exec_module(messages)


class MessagesTest(unittest.TestCase):
    def run_message(self, *args):
        return subprocess.run([sys.executable, str(HELPER), *args],
                              capture_output=True, text=True, check=False)

    def test_booking_errors_match_python_and_preserve_literal_values(self):
        for value in ["", "--unknown", "a {0} $(example)", "two\nlines"]:
            with self.subTest(value=value):
                result = self.run_message("--error", "invalid_user", "--", value)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertEqual(result.stderr, messages.message("invalid_user", value) + "\n")
                self.assertEqual(result.stderr, "Invalid user: " + value + "\n")

    def test_success_and_parameterless_diagnostic(self):
        result = self.run_message("--success", "created_booking", "123")
        self.assertEqual((result.returncode, result.stdout, result.stderr),
                         (0, "Booking created: 123\n", ""))
        result = self.run_message("--error", "booking_service_unavailable")
        self.assertEqual((result.returncode, result.stdout, result.stderr),
                         (0, "", "Booking service unavailable\n"))

    def test_invalid_calls_fail_without_tracebacks(self):
        for args in [("--error", "unknown_code"),
                     ("--error", "invalid_user"),
                     ("--error", "invalid_user", "one", "two")]:
            with self.subTest(args=args):
                result = self.run_message(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")
                self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
