"""Verify default small checkouts and explicit, integrity-checked resource fetches."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bootstrap'))
from dotfiles import cli
from dotfiles.assets import verify_rime_assets
from dotfiles.engine import Context, Failure
from dotfiles.tasks import TASKS


class AssetsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'
        self.asset = self.repo / 'config/Rime/font/example.ttf'
        self.asset.parent.mkdir(parents=True)
        self.data = b'test font bytes\n'
        self.item = dict(path='config/Rime/font/example.ttf', sha256=hashlib.sha256(self.data).hexdigest(), size=len(self.data))
        self.manifest = self.repo / 'config/Rime/lfs-manifest.json'
        self.manifest.write_text(json.dumps([self.item]))
        (self.repo / 'config/sh').mkdir()
        (self.repo / 'config/sh/xdg-ninja-patch.sh').write_text('')
        self.pointer = ('version https://git-lfs.github.com/spec/v1\n'
                        f"oid sha256:{self.item['sha256']}\nsize {self.item['size']}\n").encode()
        self.asset.write_bytes(self.pointer)

    def context(self, platform, dry=False):
        c = Context(self.repo, platform, dry_run=dry, home=self.root / 'user')
        c.tasks = dict(TASKS)
        return c

    def test_verify_pointer_and_hydrated_data(self):
        self.assertEqual(verify_rime_assets(self.repo), [self.item['path']])
        self.asset.write_bytes(self.data)
        self.assertEqual(verify_rime_assets(self.repo), [])

    def test_corrupt_or_modified_resources_are_preserved(self):
        self.asset.write_bytes(b'local edits')
        with self.assertRaisesRegex(Failure, 'differs from the manifest'):
            self.context('macos').task('rime_assets')
        self.assertEqual(self.asset.read_bytes(), b'local edits')
        self.asset.write_bytes(self.pointer.replace(b'size ', b'size 9'))
        with self.assertRaisesRegex(Failure, 'pointer does not match'):
            verify_rime_assets(self.repo)

    def test_symlink_and_parent_traversal_rejected(self):
        if os.name != 'nt':
            self.asset.unlink()
            self.asset.symlink_to(self.manifest)
            with self.assertRaisesRegex(Failure, 'symlinked'):
                verify_rime_assets(self.repo)
        self.item['path'] = 'config/Rime/../../outside'
        self.manifest.write_text(json.dumps([self.item]))
        with self.assertRaisesRegex(Failure, 'manifest path'):
            verify_rime_assets(self.repo)

    def test_mobile_plans_never_install_or_fetch_lfs(self):
        for platform in ('ish', 'termux'):
            c = self.context(platform, dry=True)
            c.task('rime_assets')
            self.assertFalse(any(e['kind'] == 'command' for e in c.events))

    def test_desktop_plans_install_lfs_only_when_needed(self):
        for platform, manager in (('macos', 'brew'), ('windows', 'scoop')):
            c = self.context(platform, dry=True)
            c.exists = lambda name: False
            c.task('rime_assets')
            commands = [e['argv'] for e in c.events if e['kind'] == 'command']
            self.assertIn([manager, 'install', 'git-lfs'], commands)
            self.assertTrue(any(a[-2:] == ['--include=config/Rime/**', '--exclude='] for a in commands))
            self.assertTrue(any('--skip-repo' in a for a in commands))

    @unittest.skipUnless(shutil.which('git-lfs') and os.name == 'posix', 'Git LFS integration requires POSIX and git-lfs')
    def test_real_lfs_default_skips_and_explicit_task_downloads(self):
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1',
                   GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.invalid',
                   GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.invalid')
        def git(cwd, *args):
            return subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-C', str(cwd), *args],
                                  env=env, capture_output=True, text=True, check=True)
        git(self.repo, 'init', '-b', 'main')
        git(self.repo, 'lfs', 'install', '--local', '--skip-repo')
        (self.repo / '.gitattributes').write_text('config/Rime/font/*.ttf filter=lfs diff=lfs merge=lfs -text\n')
        (self.repo / '.lfsconfig').write_text('[lfs]\n fetchexclude = *\n')
        self.asset.write_bytes(self.data)
        git(self.repo, 'add', '.')
        git(self.repo, 'commit', '-m', 'Resource fixture')
        remote = self.root / 'remote.git'
        git(self.root, 'init', '--bare', str(remote))
        git(self.repo, 'remote', 'add', 'origin', str(remote))
        git(self.repo, 'lfs', 'push', '--all', 'origin', 'main')
        git(self.repo, 'push', 'origin', 'main')
        clone = self.root / 'clone'
        # Enable the usual Git LFS filters: repository .lfsconfig must still skip fetch.
        subprocess.run(['git', '-c', 'filter.lfs.process=git-lfs filter-process', '-c', 'filter.lfs.required=true',
                        'clone', '-b', 'main', str(remote), str(clone)], env=env, check=True, capture_output=True)
        self.assertEqual((clone / self.item['path']).read_bytes(), self.pointer)
        self.assertFalse(any(p.is_file() for p in (clone / '.git/lfs/objects').rglob('*')))
        c = Context(clone, 'macos', home=self.root / 'user', env=env)
        c.tasks = dict(TASKS)
        c.task('rime_assets')
        self.assertEqual((clone / self.item['path']).read_bytes(), self.data)
        self.assertEqual(git(clone, 'status', '--porcelain').stdout, '')
        new_data = self.data + b'new version\n'
        (clone / self.item['path']).write_bytes(new_data)
        git(clone, 'add', self.item['path'])
        git(clone, 'commit', '-m', 'Resource update through tracked hook')
        subprocess.run(['git', '-c', 'core.hooksPath=' + str(ROOT / 'util/git/hooks'), '-C', str(clone),
                        'push', 'origin', 'main'], env=env, check=True, capture_output=True)
        self.assertTrue(any(p.is_file() and p.read_bytes() == new_data for p in (remote / 'lfs/objects').rglob('*')))
        # Restore the fixture resource before checking that repeat requires no commands.
        (clone / self.item['path']).write_bytes(self.data)
        # Repeat is local: the second run must not execute git/package commands.
        c.command = lambda *a, **kw: self.fail('already hydrated task executed a command')
        c.task('rime_assets')

