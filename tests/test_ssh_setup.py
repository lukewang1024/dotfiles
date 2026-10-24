"""Exercise service installation in an isolated filesystem with stubbed daemons."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == 'posix', 'POSIX shell required')
class SSHSetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for directory in ('etc/ssh', 'etc/init.d', 'run', 'tools'):
            (self.root / directory).mkdir(parents=True)
        (self.root / 'etc/shadow').write_text('root:hash:0:0:0:0:0:0:0\n')
        (self.root / 'etc/ssh/ssh_host_ed25519_key').touch()
        tools = self.root / 'tools'
        for name in ('id', 'apk', 'ssh-keygen', 'sshd', 'openrc', 'rc-update', 'rc-service'):
            script = tools / name
            script.write_text('''#!/bin/sh
printf '%s' "${0##*/}" >> "$HOME/calls"
printf ' <%s>' "$@" >> "$HOME/calls"
printf '\\n' >> "$HOME/calls"
case ${0##*/} in
 id) echo 0 ;;
 rc-service) exit "${SERVICE_STATUS:-0}" ;;
esac
''')
            script.chmod(0o755)
        source = (ROOT / 'util/shell/ssh-setup').read_text()
        source = source.replace('/usr/sbin/sshd', str(tools / 'sshd'))
        source = source.replace('/etc/', str(self.root / 'etc') + '/')
        source = source.replace('/run/', str(self.root / 'run') + '/')
        self.script = self.root / 'setup'
        self.script.write_text(source)
        self.env = dict(os.environ, HOME=str(self.root),
                        XDG_STATE_HOME=str(self.root / 'state'),
                        PATH=str(tools) + ':' + os.environ['PATH'])

    def run_setup(self, *args):
        return subprocess.run(['sh', str(self.script), *args], env=self.env,
                              capture_output=True, text=True)

    def test_default_installs_and_starts_persistent_service(self):
        result = self.run_setup('--port', '2226')
        self.assertEqual(result.returncode, 0, result.stderr)
        config = self.root / 'etc/ssh/sshd_config.dotfiles'
        self.assertIn('Port 2226\n', config.read_text())
        self.assertIn(str(self.root / 'run/dotfiles-sshd.pid'), config.read_text())
        service = self.root / 'etc/init.d/dotfiles-sshd'
        self.assertIn(str(config), service.read_text())
        subprocess.run(['sh', '-n', str(service)], check=True)
        calls = (self.root / 'calls').read_text()
        self.assertIn('openrc <default>', calls)
        self.assertIn('rc-update <add> <dotfiles-sshd> <default>', calls)
        self.assertIn('rc-service <dotfiles-sshd> <restart>', calls)
        self.assertIn('rc-service <dotfiles-sshd> <status>', calls)
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(len(list(config.parent.glob('*.before.*'))), 1)

    def test_service_failure_is_not_reported_as_success(self):
        self.env['SERVICE_STATUS'] = '1'
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SSH is running in background', result.stderr)

    def test_explicit_launch_modes_skip_service_install(self):
        for option, expected in (('--foreground', ' <-D> <-e>'),
                                 ('--background', ' <-E>')):
            with self.subTest(option=option):
                (self.root / 'calls').write_text('')
                result = self.run_setup(option)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = (self.root / 'calls').read_text()
                self.assertIn('sshd' + expected, calls)
                self.assertNotIn('rc-update', calls)
                self.assertFalse((self.root / 'etc/init.d/dotfiles-sshd').exists())
