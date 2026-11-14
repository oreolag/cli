import getpass
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
COMMANDS = ('new', 'build', 'program', 'run', 'delete', 'validate')


class WorkflowHelpTests(unittest.TestCase):
    def test_author_follows_selected_workflow(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'src').mkdir()
            for script in ('cmd_help_print.sh', 'workflow_command_path.sh'):
                shutil.copy(ROOT / 'src' / script, root / 'src' / script)
            personal = root / 'personal_nccl'
            community = root / 'submodules/workflows/nccl'
            personal.mkdir()
            (personal / 'GITHUB_USERNAME').write_text('personal_creator\n')
            for command in COMMANDS:
                links = root / 'users' / getpass.getuser() / 'workflows' / command
                links.mkdir(parents=True)
                (personal / f'{command}.sh').touch()
                (links / 'nccl.sh').symlink_to(personal / f'{command}.sh')

            def help_output(command, workflow='nccl'):
                return subprocess.run(
                    ['bash', str(root / 'src/cmd_help_print.sh'), '--maybe',
                     'odev', command, workflow, 'Example workflow', '0', '0', '0',
                     'name,n,Project name,-,-', '--', '--help'],
                    env={**os.environ, 'TERM': 'dumb'}, check=True,
                    text=True, capture_output=True,
                ).stdout

            for command in COMMANDS:
                self.assertIn('Created by personal_creator', help_output(command))
                self.assertNotIn('Created by', help_output(command, 'missing'))

            community.mkdir(parents=True)
            (community / 'GITHUB_USERNAME').write_text('jmoya82\n')
            for command in COMMANDS:
                (community / f'{command}.sh').touch()
                shared = root / 'cmd' / command
                shared.mkdir(parents=True)
                (shared / 'nccl.sh').symlink_to(community / f'{command}.sh')
                output = help_output(command)
                self.assertIn('Created by jmoya82', output)
                self.assertNotIn('personal_creator', output)
                self.assertLess(output.index('INHERITED FLAGS:'), output.index('Created by'))

            (community / 'GITHUB_USERNAME').unlink()
            self.assertNotIn('Created by', help_output('new'))
            (community / 'GITHUB_USERNAME').touch()
            self.assertNotIn('Created by', help_output('new'))


if __name__ == '__main__':
    unittest.main()
