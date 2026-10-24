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
        for name in ('id', 'apk', 'ssh-keygen', 'sshd', 'openrc', 'rc-update', 'rc-service', 'python3'):
            script = tools / name
            script.write_text('''#!/bin/sh
printf '%s' "${0##*/}" >> "$HOME/calls"
printf ' <%s>' "$@" >> "$HOME/calls"
printf '\\n' >> "$HOME/calls"
case ${0##*/} in
 id) echo 0 ;;
 apk) if [ "$1" = info ]; then exit "${PACKAGE_STATUS:-0}"; fi ;;
 python3) printf '%s' "${DETECTED_IP-192.0.2.4}" ;;
 openrc) mkdir -p "$HOME/run/openrc"; echo default > "$HOME/run/openrc/softlevel" ;;
 rc-update)
  mkdir -p "$HOME/etc/runlevels/default"
  ln -sf "$HOME/etc/init.d/dotfiles-sshd" "$HOME/etc/runlevels/default/dotfiles-sshd" ;;
 rc-service)
  if [ "$2" = status ] && [ "${SERVICE_STOPPED:-0}" = 1 ] &&
     [ ! -f "$HOME/service-started" ]; then exit 1; fi
  if [ "$2" = start ]; then touch "$HOME/service-started"; fi
  exit "${SERVICE_STATUS:-0}" ;;
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
        self.env.pop('SSH_CONNECTION', None)

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
        self.assertIn('./init pair ipad-ish 192.0.2.4 --port 2226', result.stderr)
        (self.root / 'calls').write_text('')
        repeated = self.run_setup('--port', '2226')
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertIn('skipping restart', repeated.stderr)
        calls = (self.root / 'calls').read_text()
        self.assertNotIn('apk <add>', calls)
        self.assertNotIn('rc-update', calls)
        self.assertNotIn('openrc <default>', calls)
        self.assertNotIn('<restart>', calls)
        self.assertNotIn('<start>', calls)
        self.assertEqual(len(list(config.parent.glob('*.before.*'))), 0)

    def test_configuration_change_backs_up_and_restarts(self):
        self.assertEqual(self.run_setup().returncode, 0)
        (self.root / 'calls').write_text('')
        self.assertEqual(self.run_setup('--port', '2223').returncode, 0)
        self.assertIn('<restart>', (self.root / 'calls').read_text())
        self.assertEqual(len(list((self.root / 'etc/ssh').glob('*.before.*'))), 1)

    def test_missing_packages_are_installed(self):
        self.env['PACKAGE_STATUS'] = '1'
        self.assertEqual(self.run_setup().returncode, 0)
        calls = (self.root / 'calls').read_text()
        self.assertIn('apk <add> <openssh-server>', calls)
        self.assertIn('apk <add> <openrc>', calls)

    def test_key_only_survives_plain_rerun(self):
        (self.root / '.ssh').mkdir()
        (self.root / '.ssh/authorized_keys').write_text('test-key\n')
        self.assertEqual(self.run_setup('--key-only').returncode, 0)
        (self.root / 'calls').write_text('')
        repeated = self.run_setup()
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertIn('PasswordAuthentication no',
                      (self.root / 'etc/ssh/sshd_config.dotfiles').read_text())
        self.assertNotIn('<restart>', (self.root / 'calls').read_text())

    def test_unknown_address_has_explicit_fallback(self):
        self.env['DETECTED_IP'] = ''
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Could not detect a local IPv4', result.stderr)
        self.assertNotIn('pair ipad-ish  --port', result.stderr)

    def test_ssh_connection_supplies_address_without_python(self):
        self.env['SSH_CONNECTION'] = '192.0.2.1 45678 192.0.2.8 2222'
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('pair ipad-ish 192.0.2.8 --port', result.stderr)
        self.assertNotIn('python3', (self.root / 'calls').read_text())

    def test_stopped_unchanged_service_is_started_without_backup(self):
        self.assertEqual(self.run_setup().returncode, 0)
        self.env['SERVICE_STOPPED'] = '1'
        (self.root / 'calls').write_text('')
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / 'calls').read_text()
        self.assertIn('rc-service <dotfiles-sshd> <start>', calls)
        self.assertNotIn('<restart>', calls)
        self.assertEqual(len(list((self.root / 'etc/ssh').glob('*.before.*'))), 0)

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

    def test_generated_service_checks_pid_contents_without_regular_file_read(self):
        self.assertEqual(self.run_setup().returncode, 0)
        service = (self.root / 'etc/init.d/dotfiles-sshd').read_text()
        function = service[service.index('running() {'):service.index('\nstart() {')]
        harness = self.root / 'check-pid'
        harness.write_text(function + '\npidfile=$1\nrunning\n')
        pidfile = self.root / 'test.pid'
        for contents, expected in [(str(os.getpid()) + '\n', 0), ('', 1),
                                   ('0\n', 1), ('1\n', 1), ('-2\n', 1),
                                   ('123\n456\n', 1), ('abc\n', 1)]:
            with self.subTest(contents=contents):
                pidfile.write_text(contents)
                result = subprocess.run(['sh', str(harness), str(pidfile)],
                                        capture_output=True, text=True, timeout=3)
                self.assertEqual(result.returncode, expected, result.stderr)
        pidfile.unlink()
        result = subprocess.run(['sh', str(harness), str(pidfile)],
                                capture_output=True, timeout=3)
        self.assertEqual(result.returncode, 1)
