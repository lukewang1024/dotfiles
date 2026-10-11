"""Exercise active SSH discovery and bounded, cached theme relay without SSH."""
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'util/shell/theme-push-remotes'


class ThemePushRemotesTests(unittest.TestCase):
    def test_discovers_workbench_without_forwarded_socket(self):
        source = SCRIPT.read_text().split("<<'PYCODE'\n", 1)[1].split('\nPYCODE', 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proc = root / 'proc'
            proc.mkdir()
            home = root / 'home'
            home.mkdir()
            processes = {
                '101': ['ssh', '-o', 'ClearAllForwardings=yes', 'cndevbox', 'exec tmux-agent-workbench client serve'],
                '102': ['ssh', '-oClearAllForwardings=yes', '-t', 'cndevbox', 'tmux-agent-workbench client attach-pty'],
                '103': ['ssh', '-p', '2222', '-i', '/private/key', 'anotherbox'],
                '104': ['ssh', 'ignored', 'THEME_SYNC_NO_PUSH=1 theme-sync dark'],
                '105': ['ssh', 'ignored', 'sftp-server'],
                '106': ['not-ssh', 'ignored'],
                '107': ['ssh', '-W', 'devbox:22', 'ignored'],
                '108': ['ssh', '-N', 'ignored'],
            }
            for pid, args in processes.items():
                entry = proc / pid
                entry.mkdir()
                (entry / 'cmdline').write_bytes(b'\0'.join(x.encode() for x in args))
            concrete_path = type(root)

            class FixturePath:
                def __new__(cls, value):
                    return proc if value == '/proc' else concrete_path(value)

                @staticmethod
                def home():
                    return home

            output = io.StringIO()
            with patch('pathlib.Path', FixturePath), redirect_stdout(output):
                exec(compile(source, str(SCRIPT), 'exec'), {})
            self.assertEqual(output.getvalue().splitlines(), ['anotherbox 103', 'cndevbox 101,102'])

    def test_caches_success_retries_failures_and_syncs_new_connections(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            discovery = bin_dir / 'python3'
            discovery.write_text('#!/bin/sh\nprintf "%s\\n" "$TEST_DESTINATION"\n')
            ssh = bin_dir / 'ssh'
            ssh.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$HOME/calls"\nexit "${TEST_EXIT:-0}"\n')
            for executable in (discovery, ssh):
                executable.chmod(0o755)
            env = dict(os.environ, HOME=str(root), XDG_STATE_HOME=str(root / 'state'),
                       PATH=str(bin_dir) + os.pathsep + os.environ['PATH'], TEST_DESTINATION='devbox 101')

            def relay(mode='dark'):
                subprocess.run(['sh', str(SCRIPT), mode], env=env, check=True, capture_output=True, timeout=12)

            relay()
            relay()
            self.assertEqual(len((root / 'calls').read_text().splitlines()), 1)
            env['TEST_DESTINATION'] = 'devbox 102'
            relay()  # Fresh attachment needs initial sync even in the same mode.
            env['TEST_EXIT'] = '1'
            relay('light')
            relay('light')
            env['TEST_EXIT'] = '0'
            relay('light')
            relay('light')
            calls = (root / 'calls').read_text().splitlines()
            self.assertEqual(len(calls), 5)
            self.assertTrue(all('-o ClearAllForwardings=yes' in line for line in calls))
            self.assertIn('theme-sync light', calls[-1])
