"""Pinned iSH prompt installation and shared shell integration, without network."""
import hashlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bootstrap'))
from dotfiles.engine import Context, Failure
from dotfiles.tasks import TASKS
from dotfiles import ish


class IshStarshipTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = {key: value for key, value in os.environ.items() if not key.startswith('XDG_')}
        self.env.update(HOME=str(self.home), XDG_DATA_HOME=str(self.home / 'data'),
                        XDG_CONFIG_HOME=str(self.home / 'config'), XDG_CACHE_HOME=str(self.home / 'cache'),
                        XDG_STATE_HOME=str(self.home / 'state'))
        self.binary = b'''#!/bin/sh
case "$1" in
  init) printf "PROMPT='shared-starship'\\nSTARSHIP_TEST_WORKERS=%s:%s\\n" "$RAYON_NUM_THREADS" "$STARSHIP_NUM_THREADS" ;;
  *) exit 7 ;;
esac
'''
        self.archive = self.package(self.binary)
        self.addCleanup(patch.stopall)
        patch.object(ish, 'ISH_STARSHIP_ARCHIVE_SHA256', self.sha(self.archive)).start()
        patch.object(ish, 'ISH_STARSHIP_BINARY_SHA256', self.sha(self.binary)).start()

    @staticmethod
    def sha(data):
        return hashlib.sha256(data).hexdigest()

    @staticmethod
    def package(binary):
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode='w:gz') as package:
            for name, content in [('starship', binary), ('LICENSE.starship', b'license'),
                                  ('BUILD.txt', b'build provenance'), ('starship-musl-main-stack.patch', b'patch')]:
                entry = tarfile.TarInfo('./' + name)
                entry.size = len(content)
                package.addfile(entry, io.BytesIO(content))
        return data.getvalue()

    def context(self):
        c = Context(ROOT, 'ish', home=self.home, env=self.env)
        c.tasks = dict(TASKS)
        return c

    def download(self, url, path):
        self.assertIn('/releases/download/ish-starship-v1.27.0-r1/', url)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(self.archive)
        return path

    def install(self):
        c = self.context()
        with patch.object(c, 'download', side_effect=self.download) as download:
            c.task('ish_starship_setup')
        self.assertEqual(download.call_count, 1)
        return c

    def test_fresh_install_and_offline_repair_use_xdg_and_verified_binary(self):
        c = self.install()
        binary = c.data / 'dotfiles/ish-starship/v1.27.0-r1/starship'
        self.assertEqual(binary.read_bytes(), self.binary)
        self.assertTrue(os.access(binary, os.X_OK))
        binary.chmod(0o600)
        (c.bin / 'starship').unlink()
        fresh = self.context()
        with patch.object(fresh, 'download', side_effect=AssertionError('repeat install used network')):
            fresh.task('ish_starship_setup')
        self.assertTrue(os.access(binary, os.X_OK))
        self.assertEqual((fresh.bin / 'starship').resolve(), ROOT / 'util/ish/starship')
        self.assertFalse((self.home / 'bin').exists())

    def test_bad_archive_preserves_existing_command_and_installation(self):
        c = self.context()
        old = c.data / 'dotfiles/ish-starship/v1.27.0-r1/starship'
        old.parent.mkdir(parents=True)
        old.write_bytes(b'existing binary')
        c.bin.mkdir(parents=True)
        command = c.bin / 'starship'
        command.write_bytes(b'existing command')
        self.archive = b'corrupt transfer'
        with patch.object(c, 'download', side_effect=self.download), self.assertRaisesRegex(Failure, 'archive failed SHA256'):
            c.task('ish_starship_setup')
        self.assertEqual(old.read_bytes(), b'existing binary')
        self.assertEqual(command.read_bytes(), b'existing command')
        self.assertFalse(list(c.cache.rglob('*.download')))

    def test_wrong_extracted_binary_is_rejected_before_replacement(self):
        c = self.context()
        old = c.data / 'dotfiles/ish-starship/v1.27.0-r1/starship'
        old.parent.mkdir(parents=True)
        old.write_bytes(b'existing binary')
        self.archive = self.package(b'wrong architecture or binary')
        with patch.object(ish, 'ISH_STARSHIP_ARCHIVE_SHA256', self.sha(self.archive)), \
             patch.object(c, 'download', side_effect=self.download), \
             self.assertRaisesRegex(Failure, 'binary failed SHA256'):
            c.task('ish_starship_setup')
        self.assertEqual(old.read_bytes(), b'existing binary')
        self.assertFalse((c.bin / 'starship').exists())

    @unittest.skipUnless(shutil.which('zsh'), 'zsh is unavailable')
    def test_ish_shell_uses_shared_prompt_and_single_worker_wrapper(self):
        c = self.install()
        env = dict(c.env, RAYON_NUM_THREADS='16', STARSHIP_NUM_THREADS='16')
        result = subprocess.run(['zsh', '-dfc', 'exists() { command -v "$1" >/dev/null; }; '
                                 'source "$1/config/zsh/prompt.zsh"; '
                                 'printf "%s:%s" "$PROMPT" "$STARSHIP_TEST_WORKERS"', 'zsh', str(ROOT)],
                                env=env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'shared-starship:1:1')
        self.assertEqual(result.stderr, '')


if __name__ == '__main__':
    unittest.main()
