"""Exercise the updater against disposable local Git repositories."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'util/shell/tmux-workbench-update'


class TmuxWorkbenchUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.plugins = self.root / 'plugins'
        self.bin_dir = self.root / 'bin'
        self.bin_dir.mkdir()
        self.state = self.root / 'state'
        self.state.mkdir()
        self.env = os.environ.copy()
        self.env.update(DOTFILES_DIR=str(self.root / 'dotfiles'),
                        AGENT_TEAM_REPO=str(self.root / 'agent-team'),
                        TMUX_PLUGIN_MANAGER_PATH=str(self.plugins),
                        XDG_BIN_HOME=str(self.bin_dir),
                        XDG_STATE_HOME=str(self.state))
        (self.bin_dir / 'tmux').write_text('#!/bin/sh\nexit 1\n')
        (self.bin_dir / 'tmux').chmod(0o755)
        self.env['PATH'] = str(self.bin_dir) + os.pathsep + self.env['PATH']

        self.repos = {}
        for name, files in {
            'dotfiles': {'init': '#!/bin/sh\nprintf "%s" "$1" > "$XDG_STATE_HOME/synced"\n'},
            'agent-team': {'install.py': 'import pathlib, sys\npathlib.Path(sys.argv[-1], "agent-team-installed").write_text("ok")\n'},
            'tmux-agent-workbench': {'install': '#!/bin/sh\nprintf "%s" "$TMUX_AGENT_WORKBENCH_RELEASE_ONLY" > "$1/workbench-installed"\n'},
            'tmux-adaptive-theme': {'theme.txt': 'v1\n'},
        }.items():
            self.repos[name] = self.make_repo(name, files)

    def git(self, *args):
        return subprocess.run(['git', *map(str, args)], check=True,
                              capture_output=True, text=True)

    def make_repo(self, name, files):
        remote = self.root / (name + '.git')
        checkout = (self.plugins if name.startswith('tmux-') else self.root) / name
        self.git('init', '--bare', '--initial-branch=main', remote)
        self.git('clone', remote, checkout)
        self.git('-C', checkout, 'config', 'user.name', 'Updater Test')
        self.git('-C', checkout, 'config', 'user.email', 'test@example.invalid')
        for filename, contents in files.items():
            path = checkout / filename
            path.write_text(contents)
            if filename in ('init', 'install'):
                path.chmod(0o755)
        (checkout / 'version.txt').write_text('v1\n')
        self.git('-C', checkout, 'add', '.')
        self.git('-C', checkout, 'commit', '-m', 'initial')
        self.git('-C', checkout, 'push', '-u', 'origin', 'main')

        writer = self.root / (name + '-writer')
        self.git('clone', remote, writer)
        self.git('-C', writer, 'config', 'user.name', 'Updater Test')
        self.git('-C', writer, 'config', 'user.email', 'test@example.invalid')
        (writer / 'version.txt').write_text('v2\n')
        self.git('-C', writer, 'add', 'version.txt')
        self.git('-C', writer, 'commit', '-m', 'update')
        self.git('-C', writer, 'push')
        return checkout

    def run_update(self, *args):
        return subprocess.run(['/bin/sh', str(SCRIPT), *args], env=self.env,
                              check=True, capture_output=True, text=True)

    def test_check_then_update_and_install_all_repositories(self):
        check = self.run_update('--check')
        for name, checkout in self.repos.items():
            self.assertIn(f'{name}: 1 update(s) available', check.stdout)
            self.assertEqual('v1\n', (checkout / 'version.txt').read_text())
        self.assertFalse((self.bin_dir / 'agent-team-installed').exists())

        update = self.run_update()
        for name, checkout in self.repos.items():
            self.assertIn(f'{name}: updated', update.stdout)
            self.assertEqual('v2\n', (checkout / 'version.txt').read_text())
        self.assertEqual('sync', (self.state / 'synced').read_text())
        self.assertEqual('ok', (self.bin_dir / 'agent-team-installed').read_text())
        self.assertEqual('1', (self.bin_dir / 'workbench-installed').read_text())

    def test_workbench_without_upstream_keeps_checkout_and_installs_release(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'branch', '--unset-upstream')

        check = self.run_update('--check')
        self.assertIn('tmux-agent-workbench: no upstream branch', check.stdout)

        update = self.run_update()
        self.assertIn('tmux-agent-workbench: warning: local/unreleased changes', update.stderr)
        self.assertEqual('v1\n', (workbench / 'version.txt').read_text())
        self.assertEqual('v2\n', (self.repos['agent-team'] / 'version.txt').read_text())
        self.assertEqual('1', (self.bin_dir / 'workbench-installed').read_text())


if __name__ == '__main__':
    unittest.main()
