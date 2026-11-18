"""Exercise the updater against disposable local Git repositories."""
import os
import io
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'util/shell/tmux-workbench-update'
MIGRATOR = SCRIPT.with_name('tmux-workbench-migrate.py')


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
                        XDG_CACHE_HOME=str(self.root / 'cache'),
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
        (self.bin_dir / 'cargo').write_text(
            '#!/bin/sh\n'
            '[ "${TEST_CARGO_FAIL:-0}" != 1 ] || exit 42\n'
            'mkdir -p "$CARGO_TARGET_DIR/release"\n'
            'cat > "$CARGO_TARGET_DIR/release/tmux-agent-workbench" <<\'EOF\'\n'
            '#!/bin/sh\n'
            'if [ "$1" = --build-marker ]; then echo current-main; '
            'else echo tmux-agent-workbench 2.0.0-beta.28; fi\n'
            'EOF\n'
            'chmod 755 "$CARGO_TARGET_DIR/release/tmux-agent-workbench"\n')
        (self.bin_dir / 'cargo').chmod(0o755)
        self.env['PATH'] = str(self.bin_dir) + os.pathsep + self.env['PATH']

        self.repos = {}
        for name, files in {
            'dotfiles': {'init': '#!/bin/sh\nprintf "%s" "$1" > "$XDG_STATE_HOME/synced"\n'},
            'agent-team': {
                'install.py': 'import pathlib, sys\npathlib.Path(sys.argv[-1], "agent-team-installed").write_text("ok")\n',
                'bin/agent-team': '#!/bin/sh\nexit 0\n',
            },
            'tmux-agent-workbench': {
                'Cargo.toml': '[package]\nname = "tmux-agent-workbench"\nversion = "2.0.0-beta.28"\n',
                'install': '#!/bin/sh\nprintf "%s" "$TMUX_AGENT_WORKBENCH_RELEASE_ONLY" > "$1/workbench-installed"\n'
                           'plugin=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)\n'
                           'ln -sf "$plugin/bin/workbench-example" "$1/workbench-example"\n'
                           'ln -sf "$plugin/bin/tmux-agent-workbench-cli" "$1/tmux-agent-workbench"\n',
                'bin/workbench-example': '#!/bin/sh\nprintf "old runtime\\n"\n',
                'bin/tmux-agent-workbench-cli': '#!/bin/sh\nexit 0\n',
                'local-notes.txt': 'original local notes\n',
                'workbench.tmux': '# original entrypoint\n',
                'src/embedded.rs': 'const _TEST: &str = include_str!("../tests/embedded.py");\n',
                'tests/embedded.py': '# original embedded input\n',
            },
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
            if filename in ('init', 'install', 'bin/agent-team', 'bin/workbench-example'):
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
        if name == 'tmux-agent-workbench':
            (writer / 'bin/workbench-example').write_text('#!/bin/sh\nprintf "new runtime\\n"\n')
            self.git('-C', writer, 'add', 'bin/workbench-example')
        self.git('-C', writer, 'add', 'version.txt')
        self.git('-C', writer, 'commit', '-m', 'update')
        self.git('-C', writer, 'push')
        if name == 'tmux-agent-workbench':
            self.git('-C', writer, 'tag', 'v2.0.0-beta.28')
            self.git('-C', writer, 'push', 'origin', 'v2.0.0-beta.28')
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
            if name == 'tmux-agent-workbench':
                self.assertIn('main checkout is aligned with the release', update.stdout)
            else:
                self.assertIn(f'{name}: updated', update.stdout)
            self.assertEqual('v2\n', (checkout / 'version.txt').read_text())
        self.assertEqual('sync', (self.state / 'synced').read_text())
        self.assertEqual('ok', (self.bin_dir / 'agent-team-installed').read_text())
        self.assertEqual('1', (self.bin_dir / 'workbench-installed').read_text())
        self.assertIn('installed tmux-agent-workbench v2.0.0-beta.28', update.stdout)
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))
        self.assertEqual('new runtime\n', subprocess.check_output([self.bin_dir / 'workbench-example'], text=True))

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

    def test_workbench_upstream_main_alias_moves_to_a_worktree_and_main_updates(self):
        workbench = self.repos['tmux-agent-workbench']
        original_main = self.git('-C', workbench, 'rev-parse', 'main').stdout.strip()
        self.git('-C', workbench, 'switch', '-c', 'upstream-main', '--track', 'origin/main')

        self.assertIn('development checkout (upstream-main)',
                      self.run_update('--check').stdout)
        self.run_update()

        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertNotEqual(original_main,
                            self.git('-C', workbench, 'rev-parse', 'main').stdout.strip())
        self.assertEqual('main',
                         self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        recovered, = (self.data / 'tmux-agent-workbench/recovered-worktrees').iterdir()
        self.assertEqual('upstream-main', self.git('-C', recovered, 'branch', '--show-current').stdout.strip())

    def test_workbench_can_create_missing_main_from_origin(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'branch', '-m', 'upstream-main')
        self.git('-C', workbench, 'fetch', 'origin', 'main:refs/remotes/origin/feature')
        self.git('-C', workbench, 'branch', '--set-upstream-to=origin/feature')

        self.run_update()
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        recovered, = (self.data / 'tmux-agent-workbench/recovered-worktrees').iterdir()
        self.assertEqual('upstream-main', self.git('-C', recovered, 'branch', '--show-current').stdout.strip())

    def test_workbench_feature_branch_and_local_changes_move_to_a_worktree(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'switch', '-c', 'ship/local-change')
        self.git('-C', workbench, 'config', 'user.name', 'Updater Test')
        self.git('-C', workbench, 'config', 'user.email', 'test@example.invalid')
        (workbench / 'local-change.txt').write_text('keep this branch\n')
        self.git('-C', workbench, 'add', 'local-change.txt')
        self.git('-C', workbench, 'commit', '-m', 'local feature work')
        (workbench / 'local-notes.txt').write_text('staged branch work\n')
        self.git('-C', workbench, 'add', 'local-notes.txt')
        (workbench / 'local-notes.txt').write_text('unfinished branch work\n')
        (workbench / 'branch-untracked.txt').write_text('branch scratch\n')
        original_head = self.git('-C', workbench, 'rev-parse', 'HEAD').stdout.strip()

        check = self.run_update('--check')
        self.assertIn('tmux-agent-workbench: development checkout (ship/local-change)', check.stdout)
        self.assertIn('tmux-agent-workbench release: v2.0.0-beta.28 published', check.stdout)

        update = self.run_update()
        recovered, = (self.data / 'tmux-agent-workbench/recovered-worktrees').iterdir()
        self.assertIn(str(recovered), update.stdout)
        self.assertEqual('ship/local-change', self.git('-C', recovered, 'branch', '--show-current').stdout.strip())
        self.assertEqual(original_head, self.git('-C', recovered, 'rev-parse', 'HEAD').stdout.strip())
        self.assertEqual('staged branch work\n', self.git('-C', recovered, 'show', ':local-notes.txt').stdout)
        self.assertEqual('unfinished branch work\n', (recovered / 'local-notes.txt').read_text())
        self.assertEqual('branch scratch\n', (recovered / 'branch-untracked.txt').read_text())
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertEqual('staged branch work\n', self.git('-C', workbench, 'show', ':local-notes.txt').stdout)
        self.assertEqual('unfinished branch work\n', (workbench / 'local-notes.txt').read_text())
        self.assertEqual('branch scratch\n', (workbench / 'branch-untracked.txt').read_text())
        self.assertFalse((workbench / 'local-change.txt').exists())
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))

    def test_feature_branch_migration_refuses_to_disturb_main_in_another_worktree(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'switch', '-c', 'feature-work')
        other = self.root / 'other-main'
        self.git('-C', workbench, 'worktree', 'add', str(other), 'main')
        (workbench / 'local-notes.txt').write_text('unfinished work\n')
        before = self.git('-C', workbench, 'status', '--porcelain').stdout

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('main is already checked out in another worktree', update.stderr)
        self.assertEqual('feature-work', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual(before, self.git('-C', workbench, 'status', '--porcelain').stdout)
        self.assertEqual('unfinished work\n', (workbench / 'local-notes.txt').read_text())
        self.assertEqual('main', self.git('-C', other, 'branch', '--show-current').stdout.strip())

    def test_conflicting_legacy_changes_remain_on_original_branch_and_main_stays_clean(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'switch', '-c', 'legacy-conflict')
        (workbench / 'version.txt').write_text('local legacy change\n')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('local changes conflict with the updated main', update.stderr)
        recovered, = (self.data / 'tmux-agent-workbench/recovered-worktrees').iterdir()
        self.assertEqual('legacy-conflict', self.git('-C', recovered, 'branch', '--show-current').stdout.strip())
        self.assertEqual('local legacy change\n', (recovered / 'version.txt').read_text())
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertEqual('', self.git('-C', workbench, 'status', '--porcelain').stdout)
        self.assertIn('workbench migration', self.git('-C', workbench, 'stash', 'list').stdout)
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))
        self.assertEqual('new runtime\n', subprocess.check_output([self.bin_dir / 'workbench-example'], text=True))
        self.assertIn('Workbench was updated, but local changes could not be reapplied', update.stderr)
        check = self.run_update('--workbench-only', '--check')
        self.assertIn('retained migration stash(es)', check.stderr)
        self.assertIn('workbench migration to workbench-recovered/', check.stderr)

    def test_detached_installation_changes_move_to_a_recovery_branch(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'checkout', '--detach')
        (workbench / 'local-notes.txt').write_text('detached work\n')
        old_head = self.git('-C', workbench, 'rev-parse', 'HEAD').stdout.strip()

        self.run_update()

        recovered, = (self.data / 'tmux-agent-workbench/recovered-worktrees').iterdir()
        self.assertEqual(old_head, self.git('-C', recovered, 'rev-parse', 'HEAD').stdout.strip())
        self.assertTrue(self.git('-C', recovered, 'branch', '--show-current').stdout.strip().startswith('workbench-recovered/'))
        self.assertEqual('detached work\n', (recovered / 'local-notes.txt').read_text())
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertEqual('detached work\n', (workbench / 'local-notes.txt').read_text())

    def test_agent_team_development_checkout_is_skipped_while_workbench_updates(self):
        workbench = self.repos['tmux-agent-workbench']
        team = self.repos['agent-team']
        self.git('-C', workbench, 'switch', '-c', 'feature-workbench')
        self.git('-C', team, 'switch', '-c', 'feature-agent-team')
        (team / 'version.txt').write_text('agent-team work\n')
        team_before = self.git('-C', team, 'status', '--porcelain').stdout

        check = self.run_update('--check')
        self.assertIn('skipping its update and installer', check.stderr)

        update = self.run_update()

        self.assertIn('checkout is on feature-agent-team', update.stderr)
        self.assertIn('complete (agent-team skipped', update.stdout)
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual('feature-agent-team', self.git('-C', team, 'branch', '--show-current').stdout.strip())
        self.assertEqual(team_before, self.git('-C', team, 'status', '--porcelain').stdout)
        self.assertEqual('agent-team work\n', (team / 'version.txt').read_text())
        self.assertFalse((self.bin_dir / 'agent-team-installed').exists())
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))

    def test_workbench_only_updates_without_touching_other_development_checkouts(self):
        workbench = self.repos['tmux-agent-workbench']
        team = self.repos['agent-team']
        self.git('-C', workbench, 'switch', '-c', 'feature-workbench')
        self.git('-C', team, 'switch', '-c', 'feature-agent-team')
        (workbench / 'local-notes.txt').write_text('workbench branch change\n')
        (team / 'version.txt').write_text('agent-team work\n')
        team_before = self.git('-C', team, 'status', '--porcelain').stdout

        check = self.run_update('--workbench-only', '--check')
        self.assertIn('development checkout (feature-workbench)', check.stdout)
        self.assertEqual('v1\n', (workbench / 'version.txt').read_text())
        self.assertFalse((self.data / 'tmux-agent-workbench/recovered-worktrees').exists())
        update = self.run_update('--workbench-only')

        self.assertIn('complete (Workbench only)', update.stdout)
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        recovered, = (self.data / 'tmux-agent-workbench/recovered-worktrees').iterdir()
        self.assertEqual('feature-workbench', self.git('-C', recovered, 'branch', '--show-current').stdout.strip())
        self.assertEqual('workbench branch change\n', (recovered / 'local-notes.txt').read_text())
        self.assertEqual('workbench branch change\n', (workbench / 'local-notes.txt').read_text())
        self.assertEqual('feature-agent-team', self.git('-C', team, 'branch', '--show-current').stdout.strip())
        self.assertEqual(team_before, self.git('-C', team, 'status', '--porcelain').stdout)
        self.assertEqual('agent-team work\n', (team / 'version.txt').read_text())
        self.assertEqual('v1\n', (self.repos['dotfiles'] / 'version.txt').read_text())
        self.assertEqual('v1\n', (self.repos['tmux-adaptive-theme'] / 'version.txt').read_text())
        self.assertFalse((self.state / 'synced').exists())
        self.assertFalse((self.bin_dir / 'agent-team-installed').exists())
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))

    def test_legacy_branch_changes_can_be_preserved_without_switching_the_branch(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'switch', '-c', 'legacy-work')
        self.git('-C', workbench, 'fetch', 'origin')
        (workbench / 'version.txt').write_text('local changes\n')
        old_head = self.git('-C', workbench, 'rev-parse', 'HEAD').stdout.strip()
        root = self.data / 'tmux-agent-workbench/recovered-worktrees'

        result = subprocess.run(['python3', str(MIGRATOR), '--repo', str(workbench),
                                 '--target', 'refs/remotes/origin/main', '--recovery-root', str(root),
                                 '--preserve-only'], env=self.env, capture_output=True, text=True, check=True)

        recovered, = root.iterdir()
        self.assertIn(str(recovered), result.stdout)
        self.assertEqual('local changes\n', (recovered / 'version.txt').read_text())
        self.assertEqual(old_head, self.git('-C', workbench, 'rev-parse', 'HEAD').stdout.strip())
        self.assertEqual('legacy-work', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual('', self.git('-C', workbench, 'status', '--porcelain').stdout)

    def test_dirty_main_changes_are_reapplied_after_update_with_index_and_untracked_files(self):
        workbench = self.repos['tmux-agent-workbench']
        (workbench / 'local-notes.txt').write_text('staged change\n')
        self.git('-C', workbench, 'add', 'local-notes.txt')
        (workbench / 'local-notes.txt').write_text('unstaged change\n')
        (workbench / 'untracked file').write_bytes(b'untracked\0data')
        (workbench / 'untracked-link').symlink_to('untracked file')
        before = self.git('-C', workbench, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout

        self.run_update('--check')
        self.assertEqual(before, self.git('-C', workbench, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout)
        self.assertFalse((self.data / 'tmux-agent-workbench/recovered-worktrees').exists())

        update = self.run_update()

        self.assertIn('reapplied local changes on updated main', update.stdout)
        self.assertEqual(before, self.git('-C', workbench, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout)
        self.assertEqual('staged change\n', self.git('-C', workbench, 'show', ':local-notes.txt').stdout)
        self.assertEqual('unstaged change\n', (workbench / 'local-notes.txt').read_text())
        self.assertEqual(b'untracked\0data', (workbench / 'untracked file').read_bytes())
        self.assertEqual('untracked file', os.readlink(workbench / 'untracked-link'))
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertEqual('new runtime\n', subprocess.check_output([self.bin_dir / 'workbench-example'], text=True))

    def test_conflicting_stash_keeps_latest_main_clean_and_preserves_recovery(self):
        workbench = self.repos['tmux-agent-workbench']
        (workbench / 'version.txt').write_text('staged conflicting change\n')
        self.git('-C', workbench, 'add', 'version.txt')
        (workbench / 'version.txt').write_text('unstaged conflicting change\n')
        (workbench / 'untracked.txt').write_text('untracked local file\n')
        before = self.git('-C', workbench, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('local changes conflict with the updated main', update.stderr)
        self.assertIn('recovery stash retained', update.stderr)
        recovered, = (self.data / 'tmux-agent-workbench/recovered-worktrees').iterdir()
        self.assertEqual(before, self.git('-C', recovered, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout)
        self.assertEqual('staged conflicting change\n', self.git('-C', recovered, 'show', ':version.txt').stdout)
        self.assertEqual('unstaged conflicting change\n', (recovered / 'version.txt').read_text())
        self.assertEqual('untracked local file\n', (recovered / 'untracked.txt').read_text())
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertEqual('', self.git('-C', workbench, 'status', '--porcelain').stdout)
        self.assertIn('workbench migration', self.git('-C', workbench, 'stash', 'list').stdout)
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))
        self.assertEqual('new runtime\n', subprocess.check_output([self.bin_dir / 'workbench-example'], text=True))
        self.assertIn('Workbench was updated, but local changes could not be reapplied', update.stderr)

    def test_main_local_runtime_changes_remain_after_install(self):
        workbench = self.repos['tmux-agent-workbench']
        install = workbench / 'install'
        install.write_text(install.read_text() + '# local installer comment\n')

        update = self.run_update()

        self.assertIn('reapplied local changes on updated main', update.stdout)
        self.assertIn('local changes are present on updated main', update.stdout)
        self.assertTrue(install.read_text().endswith('# local installer comment\n'))
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())

    def test_existing_stash_survives_migration(self):
        workbench = self.repos['tmux-agent-workbench']
        (workbench / 'local-notes.txt').write_text('older stash\n')
        self.git('-C', workbench, 'stash', 'push', '-m', 'user stash')
        before = self.git('-C', workbench, 'stash', 'list', '--format=%H %s').stdout
        (workbench / 'local-notes.txt').write_text('current work\n')

        self.run_update()

        self.assertEqual('current work\n', (workbench / 'local-notes.txt').read_text())
        self.assertEqual(before, self.git('-C', workbench, 'stash', 'list', '--format=%H %s').stdout)

    def test_concurrent_stash_from_another_worktree_is_not_mistaken_for_this_migration(self):
        workbench = self.repos['tmux-agent-workbench']
        other = self.root / 'other-worktree'
        self.git('-C', workbench, 'worktree', 'add', '-b', 'other-work', other, 'HEAD')
        (other / 'local-notes.txt').write_text('other agent work\n')
        (workbench / 'local-notes.txt').write_text('installation work\n')
        real_git = shutil.which('git', path=os.environ['PATH'])
        wrapper = self.bin_dir / 'git'
        wrapper.write_text(
            '#!/bin/sh\n'
            'case " $* " in\n'
            '  *" stash push --include-untracked "*)\n'
            f'    {shlex.quote(real_git)} "$@" || exit $?\n'
            f'    {shlex.quote(real_git)} -C {shlex.quote(str(other))} stash push -m "other agent" >/dev/null || exit $?\n'
            '    exit 0;;\n'
            'esac\n'
            f'exec {shlex.quote(real_git)} "$@"\n')
        wrapper.chmod(0o755)

        update = self.run_update()

        self.assertEqual('installation work\n', (workbench / 'local-notes.txt').read_text())
        self.assertIn('recovery stash retained', update.stdout)
        stashes = self.git('-C', workbench, 'stash', 'list').stdout
        self.assertIn('other agent', stashes)
        self.assertIn('workbench migration', stashes)
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())

    def test_failed_stash_application_restores_original_changes(self):
        workbench = self.repos['tmux-agent-workbench']
        (workbench / 'version.txt').write_text('staged\n')
        self.git('-C', workbench, 'add', 'version.txt')
        (workbench / 'version.txt').write_text('unstaged\n')
        (workbench / 'untracked.txt').write_text('keep me\n')
        before = self.git('-C', workbench, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout
        real_git = shutil.which('git', path=os.environ['PATH'])
        wrapper = self.bin_dir / 'git'
        wrapper.write_text(
            '#!/bin/sh\n'
            'case " $* " in\n'
            '  *"/recovered-worktrees/"*" stash apply --index "*) echo "injected failure" >&2; exit 1;;\n'
            'esac\n'
            f'exec {shlex.quote(real_git)} "$@"\n')
        wrapper.chmod(0o755)

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('recovery stash retained', update.stderr)
        self.assertIn('restored original changes', update.stderr)
        self.assertEqual(before, self.git('-C', workbench, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout)
        self.assertEqual('staged\n', self.git('-C', workbench, 'show', ':version.txt').stdout)
        self.assertEqual('unstaged\n', (workbench / 'version.txt').read_text())
        self.assertEqual('keep me\n', (workbench / 'untracked.txt').read_text())
        self.assertIn('2.0.0-beta.27', subprocess.check_output([self.core, '--version'], text=True))

    def test_local_main_commits_are_preserved_in_the_recovery_worktree(self):
        workbench = self.repos['tmux-agent-workbench']
        (workbench / 'local-work.txt').write_text('local commit\n')
        self.git('-C', workbench, 'add', 'local-work.txt')
        self.git('-C', workbench, 'commit', '-m', 'local work')
        old_head = self.git('-C', workbench, 'rev-parse', 'HEAD').stdout.strip()

        update = self.run_update()

        recovered, = (self.data / 'tmux-agent-workbench/recovered-worktrees').iterdir()
        self.assertIn(str(recovered), update.stdout)
        self.assertEqual(old_head, self.git('-C', recovered, 'rev-parse', 'HEAD').stdout.strip())
        self.assertEqual('local commit\n', (recovered / 'local-work.txt').read_text())
        self.assertEqual('main', self.git('-C', workbench, 'branch', '--show-current').stdout.strip())
        self.assertFalse((workbench / 'local-work.txt').exists())
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())

    def test_main_ahead_of_release_builds_and_installs_the_matching_core(self):
        writer = self.root / 'tmux-agent-workbench-writer'
        (writer / 'future.txt').write_text('not yet released\n')
        self.git('-C', writer, 'add', 'future.txt')
        self.git('-C', writer, 'commit', '-m', 'unreleased')
        self.git('-C', writer, 'push')

        check = self.run_update('--check')
        self.assertIn('update will build from source', check.stdout)
        update = self.run_update()

        self.assertIn('building the current main from source', update.stdout)
        self.assertEqual('v2\n', (self.repos['tmux-agent-workbench'] / 'version.txt').read_text())
        self.assertEqual('current-main\n', subprocess.check_output([self.core, '--build-marker'], text=True))
        self.assertEqual('0', (self.bin_dir / 'workbench-installed').read_text())
        self.assertEqual(1, self.git('-C', self.repos['tmux-agent-workbench'], 'worktree', 'list', '--porcelain').stdout.count('worktree '))

    def test_source_build_failure_preserves_the_installed_checkout_and_core(self):
        writer = self.root / 'tmux-agent-workbench-writer'
        (writer / 'future.txt').write_text('not yet released\n')
        self.git('-C', writer, 'add', 'future.txt')
        self.git('-C', writer, 'commit', '-m', 'unreleased')
        self.git('-C', writer, 'push')
        self.env['TEST_CARGO_FAIL'] = '1'

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('failed to build tmux-agent-workbench', update.stderr)
        self.assertEqual('v1\n', (self.repos['dotfiles'] / 'version.txt').read_text())
        self.assertEqual('v1\n', (self.repos['tmux-agent-workbench'] / 'version.txt').read_text())
        self.assertIn('2.0.0-beta.27', subprocess.check_output([self.core, '--version'], text=True))
        self.assertEqual(1, self.git('-C', self.repos['tmux-agent-workbench'], 'worktree', 'list', '--porcelain').stdout.count('worktree '))

    def test_post_release_tmux_entrypoint_and_test_changes_can_update_main(self):
        writer = self.root / 'tmux-agent-workbench-writer'
        (writer / 'workbench.tmux').write_text('# newer startup fix\n')
        (writer / 'tests/new-test.sh').write_text('#!/bin/sh\nexit 0\n')
        self.git('-C', writer, 'add', 'workbench.tmux', 'tests/new-test.sh')
        self.git('-C', writer, 'commit', '-m', 'fix tmux startup')
        self.git('-C', writer, 'push')

        check = self.run_update('--check')
        self.assertNotIn('do not match in core inputs', check.stderr)
        update = self.run_update()

        workbench = self.repos['tmux-agent-workbench']
        self.assertIn('compiled core inputs match the release', update.stdout)
        self.assertEqual('# newer startup fix\n', (workbench / 'workbench.tmux').read_text())
        self.assertEqual(self.git('-C', writer, 'rev-parse', 'HEAD').stdout,
                         self.git('-C', workbench, 'rev-parse', 'HEAD').stdout)
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))

    def test_post_release_test_file_embedded_in_core_triggers_source_build(self):
        writer = self.root / 'tmux-agent-workbench-writer'
        (writer / 'tests/embedded.py').write_text('# changed embedded input\n')
        self.git('-C', writer, 'add', 'tests/embedded.py')
        self.git('-C', writer, 'commit', '-m', 'change embedded input')
        self.git('-C', writer, 'push')

        update = self.run_update()

        self.assertIn('building the current main from source', update.stdout)
        self.assertEqual('v2\n', (self.repos['tmux-agent-workbench'] / 'version.txt').read_text())
        self.assertEqual('current-main\n', subprocess.check_output([self.core, '--build-marker'], text=True))

    def test_reapplied_local_core_changes_are_included_in_a_new_build(self):
        workbench = self.repos['tmux-agent-workbench']
        (workbench / 'src/embedded.rs').write_text('// local change\n')

        update = self.run_update()

        self.assertIn('reapplied local changes affect core inputs; rebuilding', update.stdout)
        self.assertEqual('// local change\n', (workbench / 'src/embedded.rs').read_text())
        self.assertEqual('current-main\n', subprocess.check_output([self.core, '--build-marker'], text=True))
        self.assertEqual('0', (self.bin_dir / 'workbench-installed').read_text())

    def test_installer_cannot_replace_source_build_with_same_version_release(self):
        writer = self.root / 'tmux-agent-workbench-writer'
        install = writer / 'install'
        install.write_text('#!/bin/sh\nprintf "#!/bin/sh\\necho tmux-agent-workbench 2.0.0-beta.28\\n" > '
                           '"$XDG_DATA_HOME/tmux-agent-workbench/bin/tmux-agent-workbench-core"\n')
        self.git('-C', writer, 'add', 'install')
        self.git('-C', writer, 'commit', '-m', 'simulate same-version stale core')
        self.git('-C', writer, 'push')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('installer provided a mismatched core; restored the verified artifact', update.stderr)
        self.assertEqual('current-main\n', subprocess.check_output([self.core, '--build-marker'], text=True))

    def test_installer_cannot_report_success_with_old_command_links(self):
        writer = self.root / 'tmux-agent-workbench-writer'
        install = writer / 'install'
        install.write_text(install.read_text().replace(
            '"$plugin/bin/workbench-example"', '"$plugin/version.txt"'))
        self.git('-C', writer, 'add', 'install')
        self.git('-C', writer, 'commit', '-m', 'simulate stale command link')
        self.git('-C', writer, 'tag', '-f', 'v2.0.0-beta.28')
        self.git('-C', writer, 'push')
        self.git('-C', writer, 'push', '-f', 'origin', 'v2.0.0-beta.28')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('command links do not match the installed checkout', update.stderr)
        self.assertNotIn('tmux-workbench-update: complete', update.stdout)

    def test_invalid_release_archive_does_not_change_the_installed_checkout_or_core(self):
        Path(self.env['TEST_RELEASE_ARCHIVE']).write_bytes(b'not a release archive')
        workbench = self.repos['tmux-agent-workbench']
        before = self.git('-C', workbench, 'rev-parse', 'HEAD').stdout
        (workbench / 'version.txt').write_text('local changes\n')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('failed to unpack tmux-agent-workbench release', update.stderr)
        self.assertEqual(before, self.git('-C', workbench, 'rev-parse', 'HEAD').stdout)
        self.assertEqual('local changes\n', (workbench / 'version.txt').read_text())
        self.assertEqual('v1\n', (self.repos['dotfiles'] / 'version.txt').read_text())
        self.assertIn('2.0.0-beta.27', subprocess.check_output([self.core, '--version'], text=True))
        self.assertFalse((self.data / 'tmux-agent-workbench/recovered-worktrees').exists())

    def test_failed_installer_restores_a_core_matching_the_updated_checkout(self):
        workbench = self.repos['tmux-agent-workbench']
        (self.bin_dir / 'workbench-example').symlink_to(workbench / 'bin/workbench-example')
        writer = self.root / 'tmux-agent-workbench-writer'
        install = writer / 'install'
        install.write_text('#!/bin/sh\nprintf "#!/bin/sh\\necho bad-core\\n" > '
                           '"$XDG_DATA_HOME/tmux-agent-workbench/bin/tmux-agent-workbench-core"\nexit 7\n')
        self.git('-C', writer, 'add', 'install')
        self.git('-C', writer, 'commit', '-m', 'simulate installer failure')
        self.git('-C', writer, 'tag', '-f', 'v2.0.0-beta.28')
        self.git('-C', writer, 'push')
        self.git('-C', writer, 'push', '-f', 'origin', 'v2.0.0-beta.28')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('failed to install tmux-agent-workbench commands', update.stderr)
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertEqual('new runtime\n', subprocess.check_output([self.bin_dir / 'workbench-example'], text=True))
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))
        self.assertNotIn('tmux-workbench-update: complete', update.stdout)

    def test_installer_that_succeeds_with_wrong_core_is_rejected_and_repaired(self):
        workbench = self.repos['tmux-agent-workbench']
        writer = self.root / 'tmux-agent-workbench-writer'
        install = writer / 'install'
        install.write_text('#!/bin/sh\nprintf "#!/bin/sh\\necho wrong-core\\n" > '
                           '"$XDG_DATA_HOME/tmux-agent-workbench/bin/tmux-agent-workbench-core"\n')
        self.git('-C', writer, 'add', 'install')
        self.git('-C', writer, 'commit', '-m', 'simulate wrong core')
        self.git('-C', writer, 'tag', '-f', 'v2.0.0-beta.28')
        self.git('-C', writer, 'push')
        self.git('-C', writer, 'push', '-f', 'origin', 'v2.0.0-beta.28')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('installer provided a mismatched core; restored the verified artifact', update.stderr)
        self.assertEqual('v2\n', (workbench / 'version.txt').read_text())
        self.assertIn('2.0.0-beta.28', subprocess.check_output([self.core, '--version'], text=True))

    def test_other_repository_failure_happens_before_workbench_source_switch(self):
        theme = self.repos['tmux-adaptive-theme']
        (theme / 'version.txt').write_text('local conflicting theme change\n')
        workbench = self.repos['tmux-agent-workbench']
        before = self.git('-C', workbench, 'rev-parse', 'HEAD').stdout

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('failed to update tmux-adaptive-theme', update.stderr)
        self.assertEqual(before, self.git('-C', workbench, 'rev-parse', 'HEAD').stdout)
        self.assertEqual('v1\n', (workbench / 'version.txt').read_text())
        self.assertIn('2.0.0-beta.27', subprocess.check_output([self.core, '--version'], text=True))

    def test_failed_migration_on_current_commit_does_not_replace_core(self):
        workbench = self.repos['tmux-agent-workbench']
        self.git('-C', workbench, 'fetch', 'origin')
        self.git('-C', workbench, 'merge', '--ff-only', 'origin/main')
        self.git('-C', workbench, 'update-index', '--assume-unchanged', 'version.txt')
        (workbench / 'version.txt').write_text('hidden local work\n')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('assume-unchanged files prevent a safe migration', update.stderr)
        self.assertEqual('hidden local work\n', (workbench / 'version.txt').read_text())
        self.assertIn('2.0.0-beta.27', subprocess.check_output([self.core, '--version'], text=True))

    def test_ignored_file_that_would_be_overwritten_blocks_update(self):
        workbench = self.repos['tmux-agent-workbench']
        (workbench / '.git/info/exclude').write_text('future.txt\n')
        (workbench / 'future.txt').write_text('keep private data\n')
        writer = self.root / 'tmux-agent-workbench-writer'
        (writer / 'future.txt').write_text('new tracked file\n')
        self.git('-C', writer, 'add', 'future.txt')
        self.git('-C', writer, 'commit', '-m', 'track future file')
        self.git('-C', writer, 'tag', '-f', 'v2.0.0-beta.28')
        self.git('-C', writer, 'push')
        self.git('-C', writer, 'push', '-f', 'origin', 'v2.0.0-beta.28')

        update = subprocess.run(['/bin/sh', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True)

        self.assertNotEqual(0, update.returncode)
        self.assertIn('ignored path would be overwritten', update.stderr)
        self.assertEqual('keep private data\n', (workbench / 'future.txt').read_text())
        self.assertEqual('v1\n', (workbench / 'version.txt').read_text())
        self.assertIn('2.0.0-beta.27', subprocess.check_output([self.core, '--version'], text=True))


if __name__ == '__main__':
    unittest.main()
