import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DeleteConfirmationTests(unittest.TestCase):
    def test_project_deletion_requires_explicit_yes(self):
        for relative in ('templates/workflows/delete.sh', 'submodules/workflows/nccl/delete.sh'):
            script = (ROOT / relative).read_text().split('# check local project\n', 1)[1]
            for answer in ('', '\n', 'n\n', 'no\n', 'anything\n', 'y\n', 'YES\n'):
                with self.subTest(script=relative, answer=answer), tempfile.TemporaryDirectory() as temp:
                    project = Path(temp) / 'nccl/example'
                    project.mkdir(parents=True)
                    (project / 'GITHUB_PUSH').write_text('1\n')
                    # A remote project must not be inspected or deleted on cancellation.
                    marker = Path(temp) / 'github_called'
                    setup = '''
PROJECTS_PATH="$TEST_ROOT"
SUBCOMMAND=nccl
name=example
ODEV_PATH="$TEST_ROOT"
COLOR_PASSED=''
normal=''
gh() { touch "$TEST_ROOT/github_called"; return 0; }
'''
                    # Supply authentication through a fixture, without reaching GitHub.
                    (Path(temp) / 'src').mkdir()
                    auth = Path(temp) / 'src/gh_auth_status.sh'
                    auth.write_text('#!/bin/sh\necho 1\n')
                    auth.chmod(0o755)
                    result = subprocess.run(['bash', '-c', setup + script], input=answer,
                                            text=True, capture_output=True,
                                            env={**os.environ, 'TEST_ROOT': temp})
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("Delete project 'example'? [y/N]:", result.stdout)
                    confirmed = answer in ('y\n', 'YES\n')
                    self.assertEqual(project.exists(), not confirmed)
                    self.assertEqual(marker.exists(), confirmed)

    def test_workflow_confirmation_guards_local_deletion(self):
        source = (ROOT / 'cmd/delete/workflow.sh').read_text()
        # Exercise the actual confirmation and deletion block without pushing changes.
        block = source.split('    # Confirm before deleting the workflow.\n', 1)[1]
        block = block.split('    # delete symlinks\n', 1)[0]
        for answer in ('', '\n', 'n\n', 'y\n', 'yes\n', 'Y\n'):
            with self.subTest(answer=answer), tempfile.TemporaryDirectory() as temp:
                workflow = Path(temp) / 'example'
                workflow.mkdir()
                result = subprocess.run(
                    ['bash', '-c', 'WORKFLOWS_USER_PATH="$TEST_ROOT"; name=example\n' + block],
                    input=answer, text=True, capture_output=True,
                    env={**os.environ, 'TEST_ROOT': temp})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Delete workflow 'example'? [y/N]:", result.stdout)
                self.assertEqual(workflow.exists(), answer not in ('y\n', 'yes\n', 'Y\n'))


if __name__ == '__main__':
    unittest.main()
