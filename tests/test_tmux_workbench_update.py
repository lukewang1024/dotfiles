"""Exercise the updater against disposable local Git repositories."""
import os
import io
import json
from pathlib import Path
import subprocess
import tarfile
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
        self.data = self.root / 'data'
        self.core = self.data / 'tmux-agent-workbench/bin/tmux-agent-workbench-core'
        self.core.parent.mkdir(parents=True)
        self.core.write_text('#!/bin/sh\nprintf "tmux-agent-workbench 2.0.0-beta.27\\n"\n')
        self.core.chmod(0o755)
        release_json = self.root / 'releases.json'
        release_json.write_text(json.dumps([
            {'tag_name': 'v2.0.0-beta.28', 'draft': False,
             'published_at': '2026-09-29T12:00:00Z', 'prerelease': True},
            {'tag_name': 'v2.0.0-beta.27', 'draft': False,
             'published_at': '2026-09-28T12:00:00Z', 'prerelease': False},
        ]))
        release_archive = self.root / 'release.tar.gz'
        binary = b'#!/bin/sh\nprintf "tmux-agent-workbench 2.0.0-beta.28\\n"\n'
        with tarfile.open(release_archive, 'w:gz') as archive:
            member = tarfile.TarInfo('tmux-agent-workbench')
            member.mode = 0o755
            member.size = len(binary)
            archive.addfile(member, io.BytesIO(binary))
        self.env = os.environ.copy()
        self.env.update(DOTFILES_DIR=str(self.root / 'dotfiles'),
                        AGENT_TEAM_REPO=str(self.root / 'agent-team'),
                        TMUX_PLUGIN_MANAGER_PATH=str(self.plugins),
                        XDG_BIN_HOME=str(self.bin_dir),
                        XDG_STATE_HOME=str(self.state),
                        XDG_DATA_HOME=str(self.data),
                        TEST_RELEASE_JSON=str(release_json),
                        TEST_RELEASE_ARCHIVE=str(release_archive))
        (self.bin_dir / 'tmux').write_text('#!/bin/sh\nexit 1\n')
        (self.bin_dir / 'tmux').chmod(0o755)
        # Never use the host's GitHub login or restart its appearance service.
        (self.bin_dir / 'gh').write_text(
            '#!/usr/bin/env python3\n'
            'import os, pathlib, sys\n'
            'if os.environ.get("TEST_GH_AUTHENTICATED") != "1": sys.exit(1)\n'
            'pathlib.Path(os.environ["XDG_STATE_HOME"], "gh-used").touch()\n'
            'print(pathlib.Path(os.environ["TEST_RELEASE_JSON"]).read_text())\n')
        (self.bin_dir / 'gh').chmod(0o755)
        (self.bin_dir / 'launchctl').write_text('#!/bin/sh\nexit 1\n')
        (self.bin_dir / 'launchctl').chmod(0o755)
        (self.bin_dir / 'curl').write_text(
            '#!/usr/bin/env python3\n'
            'import os, shutil, sys\n'
            'url = next(arg for arg in sys.argv[1:] if arg.startswith("https://"))\n'
            'destination = sys.argv[sys.argv.index("-o") + 1]\n'
            'if os.environ.get("TEST_REQUEST_LOG"):\n'
            '    with open(os.environ["TEST_REQUEST_LOG"], "a") as log: log.write(url + "\\n")\n'
            'source = os.environ["TEST_RELEASE_JSON"] if "api.github.com" in url '
            'else os.environ["TEST_RELEASE_ARCHIVE"]\n'
            'shutil.copyfile(source, destination)\n')
        (self.bin_dir / 'curl').chmod(0o755)
        (self.bin_dir / 'codesign').write_text('#!/bin/sh\nexit 0\n')
        (self.bin_dir / 'codesign').chmod(0o755)
        self.env['PATH'] = str(self.bin_dir) + os.pathsep + self.env['PATH']

        self.repos = {}
        for name, files in {
            'dotfiles': {'init': '#!/bin/sh\nprintf "%s" "$1" > "$XDG_STATE_HOME/synced"\n'},
            'agent-team': {
                'install.py': 'import pathlib, sys\npathlib.Path(sys.argv[-1], "agent-team-installed").write_text("ok")\n',
                'bin/agent-team': '#!/bin/sh\nexit 0\n',
            },
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
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents)
            if filename in ('init', 'install', 'bin/agent-team'):
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

    def test_ish_updates_use_the_compatible_32_bit_release(self):
        self.env.pop('TERMUX_VERSION', None)
        self.env.pop('PREFIX', None)
        requests = self.root / 'requested-urls'
        self.env['TEST_REQUEST_LOG'] = str(requests)
        uname = self.bin_dir / 'uname'
        uname.write_text('#!/bin/sh\ncase $1 in\n-m) echo i686;;\n-o) echo GNU/Linux;;\n*) echo Linux;;\nesac\n')
        uname.chmod(0o755)
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('/v2.0.0-beta.28/tmux-agent-workbench-i586-unknown-linux-musl.tar.gz', requests.read_text())

    def run_update(self, *args):
        return subprocess.run(['/bin/sh', str(SCRIPT), *args], env=self.env,
                              check=True, capture_output=True, text=True)

    def test_check_then_update_and_install_all_repositories(self):
        check = self.run_update('--check')
        for name, checkout in self.repos.items():
            self.assertIn(f'{name}: 1 update(s) available', check.stdout)
            self.assertEqual('v1\n', (checkout / 'version.txt').read_text())
        self.assertIn('tmux-agent-workbench release: v2.0.0-beta.28 published', check.stdout)
        self.assertIn('2.0.0-beta.27', subprocess.check_output([self.core, '--version'], text=True))
        self.assertFalse((self.bin_dir / 'agent-team-installed').exists())

        update = self.run_update()
        for name, checkout in self.repos.items():
            self.assertIn(f'{name}: updated', update.stdout)
            self.assertEqual('v2\n', (checkout / 'version.txt').read_text())
        self.assertEqual('sync', (self.state / 'synced').read_text())
        self.assertEqual('ok', (self.bin_dir / 'agent-team-installed').read_text())
        self.assertEqual('1', (self.bin_dir / 'workbench-installed').read_text())
        self.assertIn('installed tmux-agent-workbench v2.0.0-beta.28', update.stdout)
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))

    def test_workbench_without_upstream_is_rejected_before_updates(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'branch', '--unset-upstream')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)
        self.assertNotEqual(0, update.returncode)
        self.assertIn('tmux-agent-workbench main has no upstream', update.stderr)
        self.assertNotIn('fetching repositories', update.stdout)
        self.assertEqual('v1\n', (self.repos['dotfiles'] / 'version.txt').read_text())
        self.assertFalse((self.state / 'synced').exists())

    def test_agent_team_local_changes_are_preserved_while_other_repositories_update(self):
        agent_team = self.repos['agent-team']
        original_head = self.git('-C', agent_team, 'rev-parse', 'HEAD').stdout.strip()
        (agent_team / 'version.txt').write_text('local work\n')
        (agent_team / 'untracked.txt').write_text('keep me\n')

        update = self.run_update()

        self.assertIn('agent-team: warning: local/unreleased changes detected', update.stderr)
        self.assertEqual(original_head,
                         self.git('-C', agent_team, 'rev-parse', 'HEAD').stdout.strip())
        self.assertEqual('local work\n', (agent_team / 'version.txt').read_text())
        self.assertEqual('keep me\n', (agent_team / 'untracked.txt').read_text())
        self.assertEqual('ok', (self.bin_dir / 'agent-team-installed').read_text())
        for name in ('dotfiles', 'tmux-agent-workbench', 'tmux-adaptive-theme'):
            self.assertEqual('v2\n', (self.repos[name] / 'version.txt').read_text())

    def test_missing_default_agent_team_checkout_uses_the_installed_entrypoint(self):
        agent_team = self.repos['agent-team']
        self.env.pop('AGENT_TEAM_REPO')
        (self.bin_dir / 'agent-team').symlink_to(agent_team / 'bin/agent-team')

        check = self.run_update('--check')
        self.assertIn(f'agent-team: using installed checkout: {agent_team}', check.stdout)
        self.assertEqual('v1\n', (agent_team / 'version.txt').read_text())

        update = self.run_update()
        self.assertIn('agent-team: updated', update.stdout)
        self.assertEqual('v2\n', (agent_team / 'version.txt').read_text())
        self.assertEqual('ok', (self.bin_dir / 'agent-team-installed').read_text())
        self.assertFalse((self.data / 'agent-team').exists())

    def test_missing_explicit_agent_team_checkout_does_not_fall_back(self):
        missing = self.root / 'missing-agent-team'
        self.env['AGENT_TEAM_REPO'] = str(missing)
        (self.bin_dir / 'agent-team').symlink_to(self.repos['agent-team'] / 'bin/agent-team')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn(f'checkout is missing: {missing}', update.stderr)
        self.assertNotIn('fetching repositories', update.stdout)

    def test_agent_team_local_commits_are_preserved_when_upstream_diverges(self):
        agent_team = self.repos['agent-team']
        (agent_team / 'version.txt').write_text('local commit\n')
        self.git('-C', agent_team, 'add', 'version.txt')
        self.git('-C', agent_team, 'commit', '-m', 'local development')
        original_head = self.git('-C', agent_team, 'rev-parse', 'HEAD').stdout.strip()

        update = self.run_update()

        self.assertIn('agent-team: warning: local/unreleased changes detected', update.stderr)
        self.assertEqual(original_head,
                         self.git('-C', agent_team, 'rev-parse', 'HEAD').stdout.strip())
        self.assertEqual('local commit\n', (agent_team / 'version.txt').read_text())
        self.assertEqual('ok', (self.bin_dir / 'agent-team-installed').read_text())
        self.assertEqual('sync', (self.state / 'synced').read_text())
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))

    def test_authenticated_release_lookup_avoids_anonymous_api(self):
        self.env['TEST_GH_AUTHENTICATED'] = '1'
        (self.bin_dir / 'curl').write_text('#!/bin/sh\necho "anonymous API quota exhausted" >&2\nexit 22\n')
        check = self.run_update('--check')
        self.assertIn('tmux-agent-workbench release: v2.0.0-beta.28 published', check.stdout)
        self.assertTrue((self.state / 'gh-used').exists())
        self.assertFalse((self.state / 'synced').exists())

    def test_workbench_upstream_main_alias_can_update_without_touching_main(self):
        workbench = self.repos['tmux-agent-workbench']
        original_main = self.git('-C', workbench, 'rev-parse', 'main').stdout.strip()
        self.git('-C', workbench, 'switch', '-c', 'upstream-main', '--track', 'origin/main')

        self.assertIn('tmux-agent-workbench: 1 update(s) available',
                      self.run_update('--check').stdout)
        self.run_update()

        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertEqual(original_main,
                         self.git('-C', workbench, 'rev-parse', 'main').stdout.strip())
        self.assertEqual('upstream-main',
                         self.git('-C', workbench, 'branch', '--show-current').stdout.strip())

    def test_workbench_upstream_main_alias_rejects_wrong_remote_branch(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'branch', '-m', 'upstream-main')
        self.git('-C', workbench, 'fetch', 'origin', 'main:refs/remotes/origin/feature')
        self.git('-C', workbench, 'branch', '--set-upstream-to=origin/feature')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)
        self.assertNotEqual(0, update.returncode)
        self.assertIn('track a remote main branch', update.stderr)
        self.assertNotIn('fetching repositories', update.stdout)

    def test_workbench_feature_branch_is_preserved_while_latest_release_is_installed(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'switch', '-c', 'ship/local-change')
        self.git('-C', workbench, 'config', 'user.name', 'Updater Test')
        self.git('-C', workbench, 'config', 'user.email', 'test@example.invalid')
        (workbench / 'local-change.txt').write_text('keep this branch\n')
        self.git('-C', workbench, 'add', 'local-change.txt')
        self.git('-C', workbench, 'commit', '-m', 'local feature work')
        original_head = self.git('-C', workbench, 'rev-parse', 'HEAD').stdout.strip()

        check = self.run_update('--check')
        self.assertIn('tmux-agent-workbench: development checkout (ship/local-change)', check.stdout)
        self.assertIn('tmux-agent-workbench release: v2.0.0-beta.28 published', check.stdout)

        update = self.run_update()
        self.assertIn('preserving development checkout (ship/local-change)', update.stdout)
        self.assertIn('installed tmux-agent-workbench v2.0.0-beta.28', update.stdout)
        self.assertEqual(original_head,
                         self.git('-C', workbench, 'rev-parse', 'HEAD').stdout.strip())
        self.assertEqual('keep this branch\n', (workbench / 'local-change.txt').read_text())
        self.assertEqual('v1\n', (workbench / 'version.txt').read_text())
        self.assertEqual('v1\n', (self.repos['dotfiles'] / 'version.txt').read_text())
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))


if __name__ == '__main__':
    unittest.main()
