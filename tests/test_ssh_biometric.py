"""Optional installation plans and startup consent, without real biometrics."""
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bootstrap'))
from dotfiles.cli import main, select_tasks
from dotfiles.engine import Context, Failure
from dotfiles import platforms


class InstallationTests(unittest.TestCase):
    def test_optional_and_platform_scoped(self):
        self.assertEqual(select_tasks('termux', 'ssh-biometric', []),
                         [('termux_ssh_biometric_setup', [])])
        with self.assertRaises(Failure):
            select_tasks('debian', 'ssh-biometric', [])
        self.assertNotIn('termux_ssh_biometric_setup',
                         [name for name, _ in select_tasks('termux', 'core', [])])

    def test_dry_run_is_complete_and_has_no_effects(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            env = dict(os.environ, HOME=tmp,
                       XDG_CONFIG_HOME=str(home / 'config'), XDG_DATA_HOME=str(home / 'data'),
                       XDG_STATE_HOME=str(home / 'state'), XDG_CACHE_HOME=str(home / 'cache'))
            with patch.dict(os.environ, env), \
                 patch('subprocess.Popen', side_effect=AssertionError('spawned in dry run')), \
                 patch('dotfiles.engine.urlopen', side_effect=AssertionError('downloaded in dry run')):
                output = io.StringIO()
                with redirect_stdout(output):
                    self.assertEqual(main(['ssh-biometric', '--platform', 'termux', '--dry-run', '--json']), 0)
            actions = json.loads(output.getvalue())['actions']
            commands = [a['argv'] for a in actions if a['kind'] == 'command']
            self.assertTrue(any(c[:2] == ['pkg', 'install'] for c in commands))
            self.assertTrue(any(c[0] == 'sh' and c[1].endswith('/build.sh') for c in commands))
            self.assertTrue(any(c[0] == 'termux-open' for c in commands))
            links = [a for a in actions if a['kind'] == 'link']
            self.assertEqual({Path(a['target']).name for a in links},
                             {'ssh-add-biometric', 'termux-biometric-askpass'})
            self.assertEqual(list(home.iterdir()), [])


class CachedInstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        config = root / 'repo/config/sh/xdg-ninja-patch.sh'
        config.parent.mkdir(parents=True)
        config.write_text('')
        self.source = root / 'repo/tools/termux-biometric-ssh'
        for name in ('AndroidManifest.xml', 'build.sh', 'src/Main.java',
                     'bin/ssh-add-biometric', 'bin/termux-biometric-askpass'):
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('fixture')
        self.env = dict(os.environ, HOME=str(root / 'home'),
                        XDG_CONFIG_HOME=str(root / 'config'), XDG_DATA_HOME=str(root / 'data'),
                        XDG_STATE_HOME=str(root / 'state'), XDG_CACHE_HOME=str(root / 'cache'))
        self.context = Context(root / 'repo', 'termux', home=root / 'home', env=self.env)
        self.context.exists = lambda name: True
        self.builds = self.opens = 0
        self.context.command = self.command
        real_matches = platforms._sha256_matches
        mock = patch.object(platforms, '_sha256_matches', side_effect=lambda path, expected:
                            True if path.name == 'android.jar' else real_matches(path, expected))
        mock.start()
        self.addCleanup(mock.stop)

    def command(self, *args, **kwargs):
        if args[0] == 'sh':
            self.builds += 1
            build = self.context.cache / 'termux-biometric-ssh'
            build.mkdir(parents=True, exist_ok=True)
            (build / 'ssh-biometric.apk').write_bytes(b'fixture APK ' + str(self.builds).encode())
            key = self.context.state / 'termux-biometric-ssh/signing.p12'
            key.parent.mkdir(parents=True, exist_ok=True)
            if not key.exists(): key.write_bytes(b'fixture signing identity')
        elif args[0] == 'termux-open':
            self.opens += 1
            self.assertTrue(Path(args[-1]).is_file())
        return 0

    def install(self):
        platforms.termux_ssh_biometric_setup(self.context)

    def test_repeated_install_only_reopens_cached_apk(self):
        self.install(); self.install()
        self.assertEqual((self.builds, self.opens), (1, 2))

    def test_java_changes_rebuild_but_docs_do_not(self):
        self.install()
        (self.source / 'README.md').write_text('new documentation')
        self.install()
        self.assertEqual(self.builds, 1)
        (self.source / 'src/Main.java').write_text('changed source')
        self.install()
        self.assertEqual(self.builds, 2)

    def test_changed_signing_identity_rebuilds(self):
        self.install()
        (self.context.state / 'termux-biometric-ssh/signing.p12').write_bytes(b'new identity')
        self.install()
        self.assertEqual(self.builds, 2)

    def test_tampered_apk_rebuilds(self):
        self.install()
        (self.context.cache / 'termux-biometric-ssh/ssh-biometric.apk').write_bytes(b'tampered')
        self.install()
        self.assertEqual(self.builds, 2)

    def test_invalid_metadata_rebuilds(self):
        self.install()
        (self.context.cache / 'termux-biometric-ssh/build.json').write_text('invalid')
        self.install()
        self.assertEqual(self.builds, 2)

    def test_sdk_recipe_change_invalidates_fingerprint(self):
        self.install()
        key = self.context.state / 'termux-biometric-ssh/signing.p12'
        self.assertNotEqual(platforms._biometric_build_fingerprint(self.source, 'sdk-one', key),
                            platforms._biometric_build_fingerprint(self.source, 'sdk-two', key))


@unittest.skipUnless(os.name == 'posix', 'POSIX terminal required')
class ConsentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        (self.home / '.ssh').mkdir()
        (self.home / '.ssh/custom_rsa').write_text('-----BEGIN OPENSSH PRIVATE KEY-----\nsynthetic fixture\n')
        (self.home / 'bin').mkdir()
        (self.home / '.local/bin').mkdir(parents=True)
        scripts = {
            'bin/ssh-add': 'case "$1" in -l) [ "${LOADED:-0}" = 1 ] && printf "3072 SHA256:test loaded\\n"; exit 1;; *) printf plain >> "$HOME/calls";; esac',
            'bin/ssh-keygen': 'printf "3072 SHA256:test fixture\\n"',
            '.local/bin/ssh-add-biometric': 'printf biometric >> "$HOME/calls"',
        }
        for path, body in scripts.items():
            dest = self.home / path
            dest.write_text('#!/bin/sh\n' + body + '\n')
            dest.chmod(0o700)
        self.env = dict(os.environ, HOME=str(self.home), TERMUX_VERSION='test',
                        PATH=str(self.home / 'bin') + ':' + os.environ['PATH'])
        self.command = ['sh', '-c', '. "$1"; addKeys', 'sh',
                        str(ROOT / 'config/sh/ssh-agent-connect.sh')]

    def test_noninteractive_never_launches_biometrics(self):
        subprocess.run(self.command, env=self.env, input='\n', text=True, check=True,
                       capture_output=True)
        self.assertFalse((self.home / 'calls').exists())

    def terminal(self, reply, interrupt=False):
        import pty
        import signal
        import termios
        master, slave = pty.openpty()
        initial = termios.tcgetattr(slave)
        process = subprocess.Popen(self.command, env=self.env, stdin=slave, stdout=slave, stderr=slave,
                                   start_new_session=True)
        os.close(slave)
        output = b''
        try:
            while '口令输入：'.encode() not in output:
                self.assertTrue(select.select([master], [], [], 5)[0], 'prompt missing')
                output += os.read(master, 4096)
            self.assertIn('检测到 SSH 指纹工具'.encode(), output)
            self.assertFalse((self.home / 'calls').exists(), 'authentication started before Enter')
            deadline = time.monotonic() + 2
            while termios.tcgetattr(master)[3] & termios.ICANON:
                self.assertLess(time.monotonic(), deadline, 'choice reader did not enter key mode')
                time.sleep(.01)
            if interrupt:
                os.killpg(process.pid, signal.SIGINT)
                self.assertIn(process.wait(timeout=5), (0, 130, -signal.SIGINT))
            else:
                os.write(master, reply)
                self.assertEqual(process.wait(timeout=5), 0)
            deadline = time.monotonic() + 2
            while termios.tcgetattr(master) != initial and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertEqual(termios.tcgetattr(master), initial, 'terminal settings not restored')
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

    def test_enter_launches_after_explanation(self):
        self.terminal(b'\n')
        self.assertEqual((self.home / 'calls').read_text(), 'biometric')

    def test_other_input_uses_password(self):
        self.terminal(b'n\n')
        self.assertEqual((self.home / 'calls').read_text(), 'plain')

    def test_escape_uses_password_without_enter(self):
        self.terminal(b'\x1b')
        self.assertEqual((self.home / 'calls').read_text(), 'plain')

    def test_eof_cancels_without_loading(self):
        self.terminal(b'\x04')
        self.assertFalse((self.home / 'calls').exists())

    def test_interrupt_restores_terminal_without_loading(self):
        self.terminal(b'', interrupt=True)
        self.assertFalse((self.home / 'calls').exists())

    def test_biometric_failure_falls_back_to_password(self):
        helper = self.home / '.local/bin/ssh-add-biometric'
        helper.write_text('#!/bin/sh\nprintf biometric >> "$HOME/calls"\nexit 1\n')
        self.terminal(b'\n')
        self.assertEqual((self.home / 'calls').read_text(), 'biometricplain')

    def test_loaded_keys_do_not_prompt(self):
        self.env['LOADED'] = '1'
        result = subprocess.run(self.command, env=self.env, capture_output=True, text=True, check=True)
        self.assertEqual(result.stderr, '')
        self.assertFalse((self.home / 'calls').exists())

    def test_other_platform_keeps_normal_ssh_add(self):
        self.env.pop('TERMUX_VERSION')
        subprocess.run(self.command, env=self.env, check=True, capture_output=True)
        self.assertEqual((self.home / 'calls').read_text(), 'plain')

    def test_termux_without_helper_keeps_normal_ssh_add(self):
        (self.home / '.local/bin/ssh-add-biometric').unlink()
        subprocess.run(self.command, env=self.env, check=True, capture_output=True)
        self.assertEqual((self.home / 'calls').read_text(), 'plain')


if __name__ == '__main__':
    unittest.main()
