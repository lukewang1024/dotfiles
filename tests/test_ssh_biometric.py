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
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bootstrap'))
from dotfiles.cli import main, select_tasks
from dotfiles.engine import Failure


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
            links = [a for a in actions if a['kind'] == 'link']
            self.assertEqual({Path(a['target']).name for a in links},
                             {'ssh-add-biometric', 'termux-biometric-askpass'})
            self.assertEqual(list(home.iterdir()), [])


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

    def terminal(self, reply):
        import pty
        master, slave = pty.openpty()
        process = subprocess.Popen(self.command, env=self.env, stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        output = b''
        try:
            while '跳过：'.encode() not in output:
                self.assertTrue(select.select([master], [], [], 5)[0], 'prompt missing')
                output += os.read(master, 4096)
            self.assertIn('检测到 SSH 指纹工具'.encode(), output)
            self.assertFalse((self.home / 'calls').exists(), 'authentication started before Enter')
            os.write(master, reply)
            self.assertEqual(process.wait(timeout=5), 0)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

    def test_enter_launches_after_explanation(self):
        self.terminal(b'\n')
        self.assertEqual((self.home / 'calls').read_text(), 'biometric')

    def test_other_input_skips(self):
        self.terminal(b'n\n')
        self.assertFalse((self.home / 'calls').exists())

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
