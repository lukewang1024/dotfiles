"""Device pairing failure boundaries; all SSH commands are isolated stubs."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == 'posix', 'POSIX shell required')
class SSHPairTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        tools = self.home / 'tools'
        tools.mkdir()
        self.ssh = self.home / '.ssh'
        self.ssh.mkdir()
        for name in ('id_ed25519', 'id_ed25519.pub'):
            (self.ssh / name).write_text('test-only fixture\n')
        for name in ('ssh', 'ssh-keygen', 'ssh-copy-id'):
            tool = tools / name
            tool.write_text('''#!/bin/sh
printf '%s ' "${0##*/}" "$@" >> "$HOME/calls"
printf '\\n' >> "$HOME/calls"
case ${0##*/} in
 ssh-copy-id) exit "${COPY_STATUS:-0}" ;;
 ssh) exit "${SSH_STATUS:-0}" ;;
esac
''')
            tool.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(tools) + ':' + os.environ['PATH'])

    def run_pair(self, *args):
        return subprocess.run(['sh', str(ROOT / 'util/shell/ssh-pair'), *args], env=self.env,
                              capture_output=True, text=True)

    def test_pair_preserves_config_and_repeats_without_duplicate(self):
        config = self.ssh / 'config'
        original = 'Host existing\n    HostName existing.test\n'
        config.write_text(original)
        for _ in range(2):
            result = self.run_pair('ipad-ish', '192.0.2.1')
            self.assertEqual(result.returncode, 0, result.stderr)
        text = config.read_text()
        self.assertTrue(text.endswith(original))
        self.assertEqual(text.count('Host ipad-ish\n'), 1)
        self.assertTrue(list(self.ssh.glob('config.before-pair.*')))
        calls = (self.home / 'calls').read_text()
        self.assertIn('BatchMode=yes', calls)
        self.assertIn('IdentityFile=' + str(self.ssh / 'id_ed25519'), calls)
        self.assertIn('    IdentityFile "' + str(self.ssh / 'id_ed25519') + '"', text)
        self.assertNotIn('ssh-keygen', calls)
        self.assertFalse((self.ssh / 'id_ed25519_pair').exists())
        self.assertIn('StrictHostKeyChecking=yes', calls)
        self.assertIn('PreferredAuthentications=publickey', calls)
        self.assertIn('ControlPath=none', calls)
        self.assertIn('PubkeyAuthentication=yes', calls)
        self.assertIn('    PubkeyAuthentication yes\n', text)

    def test_missing_or_partial_default_pair_stops_before_ssh(self):
        for missing in [('id_ed25519',), ('id_ed25519.pub',),
                        ('id_ed25519', 'id_ed25519.pub')]:
            with self.subTest(missing=missing):
                for name in ('id_ed25519', 'id_ed25519.pub'):
                    (self.ssh / name).write_text('keep existing identity\n')
                # A legacy pairing key must never be selected as a fallback.
                (self.ssh / 'id_ed25519_pair').write_text('legacy key\n')
                for name in missing:
                    (self.ssh / name).unlink()
                before = {p.name: p.read_bytes() for p in self.ssh.iterdir()}
                result = self.run_pair('ipad', '192.0.2.1')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('./init ssh-keys', result.stderr)
                self.assertFalse((self.home / 'calls').exists())
                self.assertEqual({p.name: p.read_bytes() for p in self.ssh.iterdir()}, before)

    def test_failed_key_verification_does_not_save_alias(self):
        self.env['SSH_STATUS'] = '255'
        self.assertNotEqual(self.run_pair('ipad', '192.0.2.1').returncode, 0)
        self.assertFalse((self.ssh / 'config').exists())

    def test_failed_copy_does_not_try_verification(self):
        self.env['COPY_STATUS'] = '1'
        self.assertNotEqual(self.run_pair('ipad', '192.0.2.1').returncode, 0)
        self.assertNotIn('BatchMode=yes', (self.home / 'calls').read_text())
        self.assertFalse((self.ssh / 'config').exists())

    def test_existing_alias_is_not_overwritten(self):
        config = self.ssh / 'config'
        original = 'Host ipad other\n    HostName keep.test\n'
        config.write_text(original)
        self.assertNotEqual(self.run_pair('ipad', '192.0.2.1').returncode, 0)
        self.assertEqual(config.read_text(), original)

    def test_rejects_config_injection_before_ssh(self):
        for args in [('ipad\nHost *', '192.0.2.1'), ('ipad', '-oProxyCommand=bad'),
                     ('ipad', '192.0.2.1', '--user', 'root\nHost *'),
                     ('ipad', '192.0.2.1', '--port', '65536')]:
            self.assertNotEqual(self.run_pair(*args).returncode, 0)
        self.assertFalse((self.home / 'calls').exists())

    def test_setup_help_and_bad_port_do_not_install(self):
        script = ROOT / 'util/shell/ssh-setup'
        for args, code in [(['--help'], 0), (['--port', '22'], 2)]:
            result = subprocess.run(['sh', str(script), *args], env=self.env, capture_output=True)
            self.assertEqual(result.returncode, code)

    def test_init_routes_before_runtime_discovery_and_preserves_exit_status(self):
        checkout = self.home / 'checkout'
        checkout.mkdir()
        launcher = checkout / 'init'
        launcher.write_text((ROOT / 'init').read_text())
        helpers = checkout / 'util/shell'
        helpers.mkdir(parents=True)
        # Deliberately no bootstrap/main.py or Python runtime in this checkout.
        # Both recovery commands must route before checking for them.
        for name in ('ssh-setup', 'ssh-pair'):
            (helpers / name).write_text('#!/bin/sh\nprintf "<%s>\\n" "$@"\nexit 73\n')
        for mode, args in [('sshd', ['--key-only', '--port', '2223']),
                           ('pair', ['ipad-ish', '192.0.2.1', '--user', 'root'])]:
            result = subprocess.run(['sh', str(launcher), mode, *args],
                                    env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 73, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ['<' + arg + '>' for arg in args])
            self.assertNotIn('Preparing Python', result.stderr)

    def test_init_native_command_help(self):
        for mode in ('sshd', 'pair'):
            result = subprocess.run(['sh', str(ROOT / 'init'), mode, '--help'],
                                    env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('./init ' + mode, result.stdout)
            self.assertFalse((self.home / 'calls').exists())
