"""Exercise the one-command recovery against real disposable Git repositories."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / 'util/dotfiles/migrate-lfs'


@unittest.skipUnless(os.name == 'posix' and shutil.which('git'), 'POSIX Git fixture required')
class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1',
                        GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.invalid',
                        GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.invalid')
        self.remote = self.root / 'remote'
        self.git(self.root, 'init', '-b', 'main', str(self.remote))
        (self.remote / 'init').write_text('#!/bin/sh\nprintf synced > sync-ran\n')
        (self.remote / 'init').chmod(0o755)
        (self.remote / '.gitignore').write_text('private.local\nsync-ran\n')
        self.git(self.remote, 'add', '.')
        self.git(self.remote, 'commit', '-m', 'Old checkout')
        old = self.git(self.remote, 'rev-parse', 'HEAD').stdout.strip()
        self.target = self.root / 'dotfiles'
        self.git(self.root, 'clone', str(self.remote), str(self.target))
        self.git(self.target, 'branch', 'published-copy')
        # A separate root simulates rewritten history; the published map preserves old branches.
        self.git(self.remote, 'checkout', '--orphan', 'migrated')
        directory = self.remote / 'config/git'
        directory.mkdir(parents=True)
        (directory / 'lfs-migration.json').write_text(json.dumps(dict(version=1, commit_map='config/git/lfs-commit-map.csv')))
        self.git(self.remote, 'add', '.')
        self.git(self.remote, 'commit', '-m', 'Rewritten root')
        rewritten = self.git(self.remote, 'rev-parse', 'HEAD').stdout.strip()
        (directory / 'lfs-commit-map.csv').write_text(old + ',' + rewritten + '\n')
        self.git(self.remote, 'add', '.')
        self.git(self.remote, 'commit', '-m', 'Published mapping')
        self.git(self.remote, 'branch', '-f', 'main', 'HEAD')
        self.git(self.remote, 'checkout', 'main')
        self.git(self.remote, 'branch', '-D', 'migrated')

    def git(self, cwd, *args):
        return subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-C', str(cwd), *args],
                              env=self.env, text=True, capture_output=True, check=True)

    def migrate(self, *args, success=True):
        result = subprocess.run(['sh', str(ENTRY), '--repo', str(self.target), *args],
                                env=self.env, capture_output=True, text=True, timeout=30)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def backups(self):
        return list(self.root.glob('dotfiles.before-lfs.*'))

    def test_success_preserves_path_local_branches_ignored_files_and_backup(self):
        (self.target / 'private.local').write_text('private machine config')
        (self.target / 'private.local').chmod(0o600)
        self.git(self.target, 'config', '--local', 'user.name', 'Local Identity')
        self.git(self.target, 'config', '--local', '--add', 'credential.helper', 'fixture-helper-one')
        self.git(self.target, 'config', '--local', '--add', 'credential.helper', 'fixture-helper-two')
        with (self.target / '.git/info/exclude').open('a') as out:
            out.write('custom-private.conf\n')
        (self.target / 'custom-private.conf').write_text('local-only ignored setting')
        old = self.git(self.target, 'rev-parse', 'HEAD').stdout
        self.migrate()
        self.assertEqual(len(self.backups()), 1)
        self.assertEqual(self.git(self.backups()[0], 'rev-parse', 'HEAD').stdout, old)
        self.assertEqual((self.target / 'private.local').read_text(), 'private machine config')
        self.assertEqual((self.target / 'private.local').stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.git(self.target, 'config', '--local', 'user.name').stdout.strip(), 'Local Identity')
        self.assertEqual(self.git(self.target, 'config', '--local', '--get-all', 'credential.helper').stdout.splitlines(), ['fixture-helper-one', 'fixture-helper-two'])
        self.assertEqual((self.target / 'custom-private.conf').read_text(), 'local-only ignored setting')
        self.assertTrue((self.target / 'sync-ran').exists())
        self.assertEqual(self.git(self.target, 'status', '--porcelain').stdout, '')
        self.git(self.target, 'show', 'published-copy:config/git/lfs-migration.json')
        self.migrate()
        self.assertEqual(len(self.backups()), 1)

    def test_dirty_checkout_and_untracked_files_are_not_moved(self):
        for path in ('init', 'notes.txt'):
            before = self.git(self.target, 'rev-parse', 'HEAD').stdout
            (self.target / path).write_text('local changes')
            self.migrate(success=False)
            self.assertEqual((self.target / path).read_text(), 'local changes')
            self.assertFalse(self.backups())
            self.assertEqual(self.git(self.target, 'rev-parse', 'HEAD').stdout, before)
            if path == 'init': self.git(self.target, 'restore', 'init')
            else: (self.target / path).unlink()

    def test_unpushed_commit_refused_before_swap(self):
        (self.target / 'local.txt').write_text('unpublished')
        self.git(self.target, 'add', '.')
        self.git(self.target, 'commit', '-m', 'Local work')
        result = self.migrate(success=False)
        self.assertIn('absent from the published migration', result.stderr)
        self.assertFalse(self.backups())
        self.assertTrue((self.target / 'local.txt').exists())

    def test_check_only_leaves_checkout_unchanged(self):
        old = self.git(self.target, 'rev-parse', 'HEAD').stdout
        self.migrate('--check')
        self.assertFalse(self.backups())
        self.assertEqual(self.git(self.target, 'rev-parse', 'HEAD').stdout, old)
        self.assertFalse((self.target / 'sync-ran').exists())

    def test_sync_failure_restores_original_checkout(self):
        old = self.git(self.target, 'rev-parse', 'HEAD').stdout
        (self.remote / 'init').write_text('#!/bin/sh\nexit 9\n')
        self.git(self.remote, 'add', 'init')
        self.git(self.remote, 'commit', '-m', 'Failing sync')
        result = self.migrate(success=False)
        self.assertIn('Restored the original checkout', result.stderr)
        self.assertEqual(self.git(self.target, 'rev-parse', 'HEAD').stdout, old)
        self.assertFalse(self.backups())


    def test_stashed_work_refused(self):
        (self.target / 'init').write_text('stashed change')
        self.git(self.target, 'stash', 'push', '-m', 'Unfinished work')
        result = self.migrate(success=False)
        self.assertIn('stash/tags/notes', result.stderr)
        self.assertFalse(self.backups())
        self.assertIn('Unfinished work', self.git(self.target, 'stash', 'list').stdout)

    def test_linked_worktrees_refused(self):
        self.git(self.target, 'worktree', 'add', str(self.root / 'linked'), 'published-copy')
        result = self.migrate(success=False)
        self.assertIn('linked worktrees', result.stderr)
        self.assertFalse(self.backups())
