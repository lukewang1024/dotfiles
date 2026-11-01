"""Proxy probes may time out; the selected SSH byte stream must stay open."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == 'posix', 'POSIX shell required')
class FirstReachableTests(unittest.TestCase):
    def test_probe_timeout_does_not_become_tunnel_idle_timeout(self):
        for apple in ('0', '1'):
            with self.subTest(apple=apple), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                nc = root / 'nc'
                nc.write_text(f'#!{sys.executable}\n' + '''
import json, os, pathlib, sys
args = sys.argv[1:]
if args == ['-h']:
    if os.environ['TEST_APPLE'] == '1': print('-G conntimo')
    sys.exit(0)
with pathlib.Path(os.environ['TEST_CALLS']).open('a') as out:
    out.write(json.dumps(args)+'\\n')
if '-z' in args: sys.exit(0)
if '-w' in args: sys.exit(93)
print('tunnel remains open')
''')
                nc.chmod(0o755)
                calls = root / 'calls'
                env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                           TEST_APPLE=apple, TEST_CALLS=str(calls),
                           SSH_FIRST_REACHABLE_PARALLEL='1', SSH_FIRST_REACHABLE_TIMEOUT='3')
                result = subprocess.run(['sh', str(ROOT / 'util/shell/ssh-first-reachable'),
                                         '2222', 'device.test'], env=env,
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('tunnel remains open', result.stdout)
                probe, connection = map(json.loads, calls.read_text().splitlines())
                self.assertIn('-z', probe)
                self.assertIn('3', probe)
                self.assertNotIn('-w', connection)
                self.assertEqual(connection[-2:], ['device.test', '2222'])
