"""SSH key creation tests use private temporary homes, never user identities."""
from contextlib import redirect_stdout
import base64
import io
import json
import os
from pathlib import Path
import select
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bootstrap'))
sys.dont_write_bytecode = True
from dotfiles.cli import PLATFORMS, main
from dotfiles.engine import Context, Failure
from dotfiles.tasks import TASKS


class SSHKeyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name) / 'home with spaces'
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), USERPROFILE=str(self.home))
        for key, directory in (('XDG_CONFIG_HOME', 'config'), ('XDG_DATA_HOME', 'data'),
                               ('XDG_STATE_HOME', 'state'), ('XDG_CACHE_HOME', 'cache')):
            self.env[key] = str(self.home / directory)

    def context(self, dry=False):
        c = Context(ROOT, 'macos', home=self.home, env=self.env, dry_run=dry)
        c.tasks = TASKS
        return c

    def test_cli_dry_run_plans_both_pairs_without_prompts_or_effects(self):
        with patch.dict(os.environ, self.env), \
             patch('subprocess.Popen', side_effect=AssertionError('dry run executed a command')), \
             patch('dotfiles.engine.urlopen', side_effect=AssertionError('dry run accessed network')):
            for platform in PLATFORMS:
                with self.subTest(platform=platform):
                    output = io.StringIO()
                    with redirect_stdout(output):
                        self.assertEqual(main(['ssh-keys', '--dry-run', '--json', '--platform', platform]), 0)
                    commands = [e for e in json.loads(output.getvalue())['actions'] if e['kind'] == 'command']
                    self.assertEqual(len(commands), 2)
                    self.assertTrue(all(e['interactive'] for e in commands))
                    self.assertFalse(any(flag in e['argv'] for e in commands for flag in ('-N', '-P')))
                    self.assertEqual(list(self.home.iterdir()), [])

    def test_existing_pairs_are_preserved_without_a_terminal(self):
        directory = self.home / '.ssh'
        directory.mkdir()
        expected = {}
        for name in ('id_ed25519', 'id_rsa'):
            for suffix in ('', '.pub'):
                path = directory / (name + suffix)
                expected[path] = ('existing ' + path.name).encode()
                path.write_bytes(expected[path])
        with patch('sys.stdin.isatty', return_value=False), \
             patch('subprocess.Popen', side_effect=AssertionError('existing key was regenerated')):
            self.context().task('ssh_keys_setup')
        self.assertEqual({p: p.read_bytes() for p in directory.iterdir()}, expected)

    def test_only_missing_pair_is_planned(self):
        directory = self.home / '.ssh'
        directory.mkdir()
        (directory / 'id_ed25519').write_text('existing private key')
        (directory / 'id_ed25519.pub').write_text('existing public key')
        c = self.context(dry=True)
        c.task('ssh_keys_setup')
        commands = [e['argv'] for e in c.events if e['kind'] == 'command']
        self.assertEqual(len(commands), 1)
        self.assertEqual(Path(commands[0][-1]).name, 'id_rsa')
        self.assertFalse((directory / 'id_rsa').exists())
        self.assertEqual((directory / 'id_ed25519').read_text(), 'existing private key')

    def test_partial_pairs_are_preserved_and_fail_before_creating_any_keys(self):
        directory = self.home / '.ssh'
        directory.mkdir()
        for name in ('id_rsa', 'id_rsa.pub'):
            with self.subTest(existing=name):
                existing = directory / name
                existing.write_text('keep this file')
                try:
                    with patch('subprocess.Popen', side_effect=AssertionError('partial pair was overwritten')):
                        with self.assertRaisesRegex(Failure, 'SSH key pair|Public key exists'):
                            self.context().task('ssh_keys_setup')
                    self.assertEqual(list(directory.iterdir()), [existing])
                    self.assertEqual(existing.read_text(), 'keep this file')
                finally:
                    existing.unlink()

    def test_missing_keys_require_a_terminal_before_any_filesystem_changes(self):
        with patch('sys.stdin.isatty', return_value=False), \
             patch.object(Context, 'exists', return_value=True), \
             patch('subprocess.Popen', side_effect=AssertionError('headless key generation')):
            with self.assertRaisesRegex(Failure, 'interactive terminal'):
                self.context().task('ssh_keys_setup')
        self.assertEqual(list(self.home.iterdir()), [])

    @unittest.skipIf(os.name == 'nt', 'POSIX pseudo-terminal')
    @unittest.skipUnless(shutil.which('ssh-keygen'), 'OpenSSH key generator')
    def test_real_passphrase_prompts_create_encrypted_pairs_without_logging_input(self):
        import pty

        # A disposable test value, never a user's passphrase or key.
        passphrase = b'dotfiles-disposable-key-test'
        env = dict(self.env)
        for name in ('SSH_ASKPASS', 'SSH_ASKPASS_REQUIRE'):
            env.pop(name, None)
        pid, fd = pty.fork()
        if pid == 0:
            os.execve(sys.executable, [sys.executable, '-B', str(ROOT / 'bootstrap/main.py'), 'ssh-keys'], env)
        transcript = b''
        pending = b''
        prompts = (b'Enter passphrase', b'Enter same passphrase again')
        answers = 0
        finished = False
        deadline = time.monotonic() + 40
        try:
            while time.monotonic() < deadline:
                if select.select([fd], [], [], .1)[0]:
                    try:
                        chunk = os.read(fd, 65536)
                    except OSError:
                        chunk = b''
                    transcript += chunk
                    pending += chunk
                    while answers < 4:
                        marker = prompts[answers % 2]
                        position = pending.find(marker)
                        if position < 0:
                            break
                        pending = pending[position + len(marker):]
                        os.write(fd, passphrase + b'\n')
                        answers += 1
                ended, status = os.waitpid(pid, os.WNOHANG)
                if ended:
                    finished = True
                    self.assertEqual(os.waitstatus_to_exitcode(status), 0, transcript.decode(errors='replace'))
                    break
            self.assertTrue(finished, 'Interactive key generation timed out: ' + transcript.decode(errors='replace'))
        finally:
            if not finished:
                os.killpg(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
            os.close(fd)
        self.assertEqual(answers, 4)
        self.assertNotIn(passphrase, transcript)
        directory = self.home / '.ssh'
        self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
        snapshot = {p: p.read_bytes() for p in directory.iterdir()}
        for name, kind, bits in (('id_ed25519', 'ED25519', '256'), ('id_rsa', 'RSA', '3072')):
            private = directory / name
            self.assertEqual(private.stat().st_mode & 0o777, 0o600)
            data = base64.b64decode(b''.join(private.read_bytes().splitlines()[1:-1]))
            magic = b'openssh-key-v1\0'
            self.assertTrue(data.startswith(magic))
            length = struct.unpack('>I', data[len(magic):len(magic) + 4])[0]
            self.assertNotEqual(data[len(magic) + 4:len(magic) + 4 + length], b'none')
            result = subprocess.run(['ssh-keygen', '-lf', str(directory / (name + '.pub'))],
                                    capture_output=True, text=True, check=True)
            self.assertTrue(result.stdout.startswith(bits + ' '), result.stdout)
            self.assertIn('(' + kind + ')', result.stdout)
        rerun = subprocess.run([sys.executable, '-B', str(ROOT / 'bootstrap/main.py'), 'ssh-keys'],
                               env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=10)
        self.assertEqual(rerun.returncode, 0, rerun.stderr.decode(errors='replace'))
        self.assertEqual({p: p.read_bytes() for p in directory.iterdir()}, snapshot)
        for log in (self.home / 'state/dotfiles/bootstrap').glob('*/output.log'):
            self.assertNotIn(passphrase, log.read_bytes())


if __name__ == '__main__':
    unittest.main()
