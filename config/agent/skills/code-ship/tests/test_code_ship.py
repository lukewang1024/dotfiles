"""Offline policy and shipping integration tests using local bare remotes."""
import importlib.util
import json
import os
import pty
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/code-ship.py'
spec = importlib.util.spec_from_file_location('code_ship', SCRIPT)
ship_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ship_module)


class ShippingTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.remote = self.root / 'origin.git'
        self.repo = self.root / 'repo'
        self.config = self.root / 'config/code-ship/config.yml'
        self.env = {**os.environ, 'GIT_CONFIG_NOSYSTEM': '1',
                    'GIT_CONFIG_GLOBAL': '/dev/null', 'LC_ALL': 'C',
                    'XDG_CONFIG_HOME': str(self.root / 'config')}
        self.env.pop('CODE_SHIP_DRY_RUN', None)
        self.env.pop('GIT_DIR', None)
        self.env.pop('GIT_WORK_TREE', None)

    def command(self, *args, cwd=None, check=True):
        return subprocess.run(args, cwd=cwd or self.root, env=self.env,
                              text=True, capture_output=True, check=check,
                              stdin=subprocess.DEVNULL)

    def git(self, *args):
        return self.command('git', *args, cwd=self.repo).stdout.strip()

    def setup_repo(self, branch='main'):
        self.command('git', 'init', '--bare', f'--initial-branch={branch}', str(self.remote))
        self.command('git', 'clone', str(self.remote), str(self.repo))
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.com')
        self.commit('base')
        self.git('push', 'origin', branch)
        self.commit('change')

    def commit(self, text):
        (self.repo / 'file').write_text(text)
        self.git('add', '.')
        self.git('commit', '-m', text)

    def ship(self, *args):
        return self.command(sys.executable, str(SCRIPT), '--repo-dir', str(self.repo),
                            *args, check=False)

    def configure(self, strategy='direct-push', *args):
        result = self.ship('--configure', '--strategy', strategy, *args)
        self.assertEqual(result.returncode, 0, result.stderr)

    def remote_head(self, branch='main'):
        return self.command('git', '--git-dir', str(self.remote), 'rev-parse', branch).stdout.strip()

    def test_first_use_requires_choice_without_writes(self):
        self.setup_repo()
        before = self.remote_head()
        result = self.ship()
        self.assertEqual(result.returncode, 20, result.stderr)
        self.assertEqual(json.loads(result.stdout)['status'], 'needs-policy')
        self.assertFalse(self.config.exists())
        self.assertEqual(self.remote_head(), before)
        self.assertEqual(self.git('status', '--porcelain'), '')

    def test_interactive_first_choice_is_saved(self):
        self.setup_repo()
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen([sys.executable, str(SCRIPT), '--repo-dir', str(self.repo), '--configure'],
                                       env=self.env, stdin=slave, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, text=True)
            os.write(master, b'1\n')
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertEqual(json.loads(stdout[stdout.index('{'):])['policy']['strategy'], 'direct-push')
            self.assertTrue(self.config.exists())
        finally:
            os.close(master)
            os.close(slave)

    def test_configure_only_then_master_push(self):
        self.setup_repo('master')
        before = self.remote_head('master')
        self.configure()
        self.assertEqual(self.remote_head('master'), before)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.git('status', '--porcelain'), '')
        result = self.ship()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remote_head('master'), self.git('rev-parse', 'HEAD'))

    def test_explicit_override_does_not_save(self):
        self.setup_repo()
        self.configure('manual-merge', '--provider', 'example')
        before = self.config.read_text()
        result = self.ship('--strategy', 'direct-push')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.config.read_text(), before)

    def test_first_explicit_override_is_temporary(self):
        self.setup_repo()
        self.assertEqual(self.ship('--strategy', 'direct-push').returncode, 0)
        self.assertFalse(self.config.exists())

    def test_remember_updates_default(self):
        self.setup_repo()
        self.configure('manual-merge', '--provider', 'example')
        result = self.ship('--strategy', 'direct-push', '--remember')
        self.assertEqual(result.returncode, 0, result.stderr)
        result = json.loads(self.ship('--show-policy').stdout)
        self.assertEqual(result['policy']['strategy'], 'direct-push')

    def test_clone_and_worktree_share_policy(self):
        self.setup_repo()
        self.configure()
        clone = self.root / 'clone'
        self.command('git', 'clone', str(self.remote), str(clone))
        worktree = self.root / 'worktree'
        self.git('worktree', 'add', '-b', 'feature', str(worktree))
        for path in (clone, worktree):
            result = self.command(sys.executable, str(SCRIPT), '--repo-dir', str(path), '--show-policy')
            self.assertEqual(json.loads(result.stdout)['policy']['strategy'], 'direct-push')

    def test_url_normalization(self):
        variants = ['git@example.com:Owner/Repo.git', 'https://example.com/Owner/Repo',
                    'ssh://git@EXAMPLE.COM:22/Owner/Repo.git',
                    'https://user:secret@example.com:443/Owner/Repo.git/']
        self.assertEqual({ship_module.identity(url)[0] for url in variants}, {'example.com/Owner/Repo'})
        self.assertNotEqual(ship_module.identity('ssh://git@example.com:2222/Owner/Repo')[0], 'example.com/Owner/Repo')

    def test_github_ssh_alias_selects_builtin_provider(self):
        self.setup_repo()
        self.git('remote', 'set-url', 'origin', 'git@github.com-geek:Owner/Repo.git')
        self.git('remote', 'set-url', '--push', 'origin', 'git@github.com-geek:Owner/Repo.git')
        result = self.ship('--show-policy')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['policy']['provider'], 'github')

    def test_builtin_github_merge_waits_for_all_checks_and_exact_head(self):
        pending = {'state': 'OPEN', 'headRefOid': 'head-sha',
                   'statusCheckRollup': [{'status': 'IN_PROGRESS', 'conclusion': ''}]}
        ready = {**pending, 'statusCheckRollup': [{'status': 'COMPLETED', 'conclusion': 'SUCCESS'}]}
        statuses = iter([{**pending, 'statusCheckRollup': []}, pending, ready,
                         {**ready, 'state': 'MERGED', 'mergeCommit': {'oid': 'merge-sha'}}])
        calls = []
        def fake_run(*args, capture=True):
            calls.append(args)
            return json.dumps(next(statuses)) if args[:3] == ('gh', 'pr', 'view') else ''
        with patch.object(ship_module, 'run', side_effect=fake_run), patch.object(ship_module.time, 'sleep'):
            result = ship_module.github_auto_merge('Owner/Repo', '7', 'head-sha', 'Title', 'Body', 1, 10)
        merges = [c for c in calls if c[:3] == ('gh', 'pr', 'merge')]
        self.assertEqual(result['mergeCommit']['oid'], 'merge-sha')
        self.assertEqual(len(merges), 1)
        self.assertEqual(calls.index(merges[0]), 3)
        self.assertIn('--match-head-commit', merges[0])
        self.assertNotIn('--auto', merges[0])

    def test_builtin_github_merge_does_not_replay_unknown_mutation(self):
        ready = {'state': 'OPEN', 'headRefOid': 'head-sha',
                 'statusCheckRollup': [{'status': 'COMPLETED', 'conclusion': 'SUCCESS'}]}
        statuses = iter([ready, {**ready, 'state': 'MERGED'}])
        attempts = []
        def fake_run(*args, capture=True):
            if args[:3] == ('gh', 'pr', 'merge'):
                attempts.append(args)
                raise subprocess.CalledProcessError(1, args)
            return json.dumps(next(statuses))
        with patch.object(ship_module, 'run', side_effect=fake_run), patch.object(ship_module.time, 'sleep'):
            ship_module.github_auto_merge('Owner/Repo', '7', 'head-sha', '', '', 1, 10)
        self.assertEqual(len(attempts), 1)

    def test_builtin_github_merge_refuses_failed_changed_or_unverified_merged(self):
        for status in [
            {'state': 'OPEN', 'headRefOid': 'other', 'statusCheckRollup': []},
            {'state': 'OPEN', 'headRefOid': 'head-sha', 'statusCheckRollup': [{'conclusion': 'FAILURE'}]},
            {'state': 'MERGED', 'headRefOid': 'head-sha', 'statusCheckRollup': []},
        ]:
            with self.subTest(status=status), patch.object(ship_module, 'run', return_value=json.dumps(status)) as run:
                with self.assertRaises(ValueError):
                    ship_module.github_auto_merge('Owner/Repo', '7', 'head-sha', '', '', 1, 10)
                self.assertEqual(run.call_count, 1)

    def test_saved_identity_contains_no_credentials(self):
        self.setup_repo()
        self.git('remote', 'set-url', 'origin', 'https://user:secret@example.com/owner/repo.git')
        self.configure()
        self.assertNotIn('secret', self.config.read_text())
        self.assertIn('example.com/owner/repo', self.config.read_text())

    def test_feature_push_preserves_branches(self):
        self.setup_repo()
        self.configure()
        main = self.git('rev-parse', 'main')
        self.git('checkout', '-b', 'feature')
        self.commit('feature')
        self.assertEqual(self.ship().returncode, 0)
        self.assertEqual(self.remote_head(), self.git('rev-parse', 'HEAD'))
        self.assertEqual(self.git('rev-parse', 'main'), main)
        self.assertEqual(self.git('branch', '--show-current'), 'feature')

    def test_divergence_and_dirty_tree_rejected(self):
        self.setup_repo()
        self.configure()
        self.git('checkout', '-b', 'other', 'origin/main')
        self.commit('other')
        self.git('push', 'origin', 'HEAD:main')
        self.git('checkout', 'main')
        before = self.remote_head()
        self.assertNotEqual(self.ship().returncode, 0)
        self.assertEqual(self.remote_head(), before)
        (self.repo / 'file').write_text('dirty')
        self.assertIn('working tree not clean', self.ship().stderr)

    def test_dry_run_has_no_publish_or_config_effects(self):
        self.setup_repo()
        before = self.remote_head()
        self.assertEqual(self.ship('--strategy', 'direct-push', '--dry-run').returncode, 0)
        self.assertEqual(self.remote_head(), before)
        self.assertFalse(self.config.exists())
        self.assertNotEqual(self.ship('--strategy', 'direct-push', '--dry-run', '--remember').returncode, 0)
        self.assertFalse(self.config.exists())

    def test_missing_provider_before_branch_or_push(self):
        self.setup_repo()
        self.configure('manual-merge', '--provider', 'nonexistent-test-provider')
        before = self.remote_head()
        result = self.ship()
        self.assertIn('missing code-ship-provider-', result.stderr)
        self.assertEqual(self.git('branch', '--show-current'), 'main')
        self.assertEqual(self.remote_head(), before)

    def test_squash_delivered_content_does_not_republish(self):
        self.setup_repo()
        self.git('checkout', '-b', 'feature')
        self.commit('feature')
        feature_head = self.git('rev-parse', 'HEAD')
        self.git('checkout', '-b', 'integrated', 'origin/main')
        self.git('merge', '--squash', 'feature')
        self.git('commit', '-m', 'squashed delivery')
        self.git('push', 'origin', 'HEAD:main')
        self.git('checkout', 'feature')
        bindir = self.root / 'bin'
        bindir.mkdir()
        marker = self.root / 'published'
        adapter = bindir / 'code-ship-provider-example'
        adapter.write_text('#!/bin/sh\nset -eu\n[ "${1:-}" != --check ] || exit 0\ntouch "$PUBLISH_MARKER"\n')
        adapter.chmod(0o755)
        self.env['PATH'] = str(bindir) + ':' + self.env['PATH']
        self.env['PUBLISH_MARKER'] = str(marker)
        self.configure('auto-merge', '--provider', 'example')
        before = self.remote_head()
        for args in [(), ('--dry-run',)]:
            result = self.ship(*args)
            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = json.loads(result.stdout)
            self.assertEqual(receipt['status'], 'no-content-change')
            self.assertGreater(receipt['commitsAhead'], 0)
            self.assertFalse(marker.exists())
            self.assertEqual(self.remote_head(), before)
            self.assertEqual(self.git('rev-parse', 'HEAD'), feature_head)
            self.assertEqual(self.git('branch', '--show-current'), 'feature')
            self.assertEqual(self.git('status', '--porcelain'), '')

    def test_provider_receives_resolved_context(self):
        self.setup_repo()
        bindir = self.root / 'bin'
        bindir.mkdir()
        adapter = bindir / 'code-ship-provider-example'
        adapter.write_text('#!/bin/sh\nset -eu\n[ "${1:-}" != --check ] || exit 0\nprintf \'%s\\n\' "$STRATEGY:$TARGET_BRANCH:$FEATURE_BRANCH"\n')
        adapter.chmod(0o755)
        self.env['PATH'] = str(bindir) + ':' + self.env['PATH']
        self.configure('manual-merge', '--provider', 'example')
        before = self.git('rev-parse', 'main')
        result = self.ship()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('manual-merge:main:ship/', result.stdout)
        self.assertEqual(self.git('rev-parse', 'main'), before)

    def test_repository_configs_ignored(self):
        self.setup_repo()
        (self.repo / '.skill-config.yml').write_text('code-ship:\n  strategy: direct-push\n')
        self.git('config', 'code-ship.strategy', 'direct-push')
        self.assertEqual(self.ship().returncode, 20)

    def test_target_override_and_reset(self):
        self.setup_repo()
        self.configure('direct-push', '--target-branch', 'missing')
        saved = self.config.read_text()
        self.assertEqual(self.ship('--target-branch', 'main', '--dry-run').returncode, 0)
        self.assertEqual(self.config.read_text(), saved)
        self.configure('direct-push', '--target-branch', 'auto')
        self.assertEqual(self.ship().returncode, 0)

    def test_different_push_destination_rejected(self):
        self.setup_repo()
        self.git('remote', 'set-url', '--push', 'origin', str(self.root / 'other.git'))
        self.assertIn('fetch and push repositories differ', self.ship('--show-policy').stderr)

    def test_malformed_config_preserved(self):
        self.setup_repo()
        self.config.parent.mkdir(parents=True)
        self.config.write_text('not a valid config')
        self.assertNotEqual(self.ship('--configure', '--strategy', 'direct-push').returncode, 0)
        self.assertEqual(self.config.read_text(), 'not a valid config')


if __name__ == '__main__':
    unittest.main()
