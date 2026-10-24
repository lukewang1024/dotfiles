"""iSH runtime selection without executing provisioning or system Python."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == 'posix', 'POSIX launcher required')
class ISHRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'checkout'
        (self.repo / 'util/ish').mkdir(parents=True)
        (self.repo / 'bootstrap').mkdir()
        (self.repo / 'bootstrap/main.py').touch()
        shutil.copy2(ROOT / 'init', self.repo / 'init')
        shutil.copy2(ROOT / 'util/ish/python3', self.repo / 'util/ish/python3')
        self.tools = self.root / 'tools'
        self.tools.mkdir()
        self.write_tool('uname', '#!/bin/sh\ncase $1 in -s) echo Linux ;; -r) echo "${TEST_RELEASE:-4.20.69-ish}" ;; esac\n')
        self.data = self.root / 'data with spaces'
        self.runtime = self.data / 'dotfiles/ish-python/usr'
        (self.runtime / 'bin').mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.root), XDG_DATA_HOME=str(self.data),
                        PATH=str(self.tools) + ':' + os.environ['PATH'], LD_LIBRARY_PATH='/test/existing')

    def write_tool(self, name, text):
        path = self.tools / name
        path.write_text(text)
        path.chmod(0o755)

    def run_init(self, *args):
        return subprocess.run(['sh', str(self.repo / 'init'), *args], env=self.env,
                              capture_output=True, text=True, timeout=5)

    def test_managed_runtime_precedes_broken_system_python_and_preserves_arguments(self):
        self.write_tool('python3', '#!/bin/sh\necho broken-system >&2\nexit 99\n')
        python = self.runtime / 'bin/python3.12'
        python.write_text('#!/bin/sh\nprintf "%s\\n" "$PYTHONHOME" "$LD_LIBRARY_PATH" "$@"\nexit 37\n')
        python.chmod(0o755)
        result = self.run_init('core', '--dry-run', '--json')
        self.assertEqual(result.returncode, 37, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [str(self.runtime),
                         str(self.runtime / 'lib') + ':/test/existing',
                         str(self.repo / 'bootstrap/main.py'), 'core', '--dry-run', '--json'])
        self.assertNotIn('broken-system', result.stderr)

    def test_other_platforms_use_existing_runtime_discovery(self):
        self.env['TEST_RELEASE'] = '6.1.0'
        python = self.runtime / 'bin/python3.12'
        python.write_text('#!/bin/sh\nexit 99\n')
        python.chmod(0o755)
        self.write_tool('python3', '#!/bin/sh\n[ "$1" != -c ] || exit 0\nprintf "%s\\n" "$@"\nexit 23\n')
        result = self.run_init('core')
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [str(self.repo / 'bootstrap/main.py'), 'core'])

    def test_ish_runtime_probes_use_timeout_and_inspection_never_installs(self):
        self.write_tool('python3', '#!/bin/sh\nexit 99\n')
        self.write_tool('python', '#!/bin/sh\nexit 99\n')
        self.write_tool('timeout', '#!/bin/sh\necho timed-probe >> "$HOME/probes"\nexit 143\n')
        self.write_tool('apk', '#!/bin/sh\ntouch "$HOME/unexpected-install"\nexit 99\n')
        result = self.run_init('--help')
        self.assertEqual(result.returncode, 1)
        self.assertTrue((self.root / 'probes').exists())
        self.assertFalse((self.root / 'unexpected-install').exists())
