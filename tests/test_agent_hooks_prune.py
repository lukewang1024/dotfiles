"""Run hook pruning only against isolated, disposable home directories."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

try:
    import tomllib
except ImportError:
    tomllib = None


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(tomllib and shutil.which('jq') and os.name == 'posix',
                     'requires Python 3.11+, POSIX sh and jq')
class HookPruneTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / 'config'),
                        XDG_STATE_HOME=str(self.home / 'state'))
        self.env['PATH'] = str(Path(sys.executable).parent) + os.pathsep + self.env['PATH']
        (self.home / '.codex').mkdir()
        (self.home / '.claude').mkdir()
        self.source = self.home / '.codex/hooks.json'
        self.config = self.home / '.codex/config.toml'
        self.keep = self.home / 'keep.txt'
        self.keep.write_text('tmux-agent-workbench hook ingest\ntmux-agent-workbench.js\n')
        self.deny = self.home / 'deny.txt'
        self.deny.write_text('')

    def run_prune(self, *args):
        return subprocess.run(['/bin/sh', str(ROOT / 'util/agent/agent-hooks-prune'),
                               '--keep-file', str(self.keep), '--deny-file', str(self.deny),
                               *args], env=self.env, capture_output=True, text=True)

    def fixture(self):
        foreign = {'type': 'command', 'command': '/home/example/.orca/agent-hooks/codex-hook.sh'}
        kept = {'type': 'command', 'command': 'tmux-agent-workbench hook ingest codex Stop'}
        root = {'metadata': True, 'hooks': {'Stop': [
            {'hooks': [foreign]}, {'hooks': [foreign, kept]}
        ]}}
        self.source.write_text(json.dumps(root))
        (self.home / '.claude/settings.json').write_text(json.dumps(root))
        text = 'model = "keep-model"\n[hooks.state]\n'
        for g, h, digest in ((0, 0, 'removed-one'), (1, 0, 'removed-two'), (1, 1, 'kept')):
            key = f'{self.source}:stop:{g}:{h}'
            text += f'[hooks.state.{json.dumps(key)}]\ntrusted_hash = "{digest}"\nenabled = false\n'
        self.config.write_text(text)
        plugin = self.home / 'config/opencode/plugins/tmux-agent-workbench.js'
        plugin.parent.mkdir(parents=True)
        plugin.write_text('// kept')

    def test_dry_run_apply_reviews_backup_and_idempotence(self):
        self.fixture()
        originals = (self.source.read_bytes(), self.config.read_bytes())
        result = self.run_prune()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('would remove codex Stop', result.stdout)
        self.assertEqual(originals, (self.source.read_bytes(), self.config.read_bytes()))
        self.assertFalse((self.home / 'state').exists())
        result = self.run_prune('--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('.orca', self.source.read_text())
        self.assertNotIn('.orca', (self.home / '.claude/settings.json').read_text())
        state = tomllib.loads(self.config.read_text())
        self.assertEqual(state['model'], 'keep-model')
        self.assertEqual(state['hooks']['state'], {
            f'{self.source}:stop:0:0': {'trusted_hash': 'kept', 'enabled': False}
        })
        backups = list((self.home / 'state').glob('agent-hooks-prune/archive/*/.codex/config.toml'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), originals[1])
        self.assertTrue((self.home / 'config/opencode/plugins/tmux-agent-workbench.js').exists())
        first = (self.source.read_bytes(), self.config.read_bytes())
        result = self.run_prune('--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(first, (self.source.read_bytes(), self.config.read_bytes()))

    def test_unsupported_state_layout_fails_before_changing_codex(self):
        self.fixture()
        key = f'{self.source}:stop:1:1'
        self.config.write_text('hooks = { state = { ' + json.dumps(key) +
                               ' = { trusted_hash = "kept" } } }\n')
        before = (self.source.read_bytes(), self.config.read_bytes())
        result = self.run_prune('--apply')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('cannot preserve Codex hook reviews', result.stderr)
        self.assertEqual(before, (self.source.read_bytes(), self.config.read_bytes()))

    def test_explicit_deny_overrides_keep(self):
        self.fixture()
        self.keep.write_text(self.keep.read_text() + '.orca/agent-hooks/\n')
        self.deny.write_text('.orca/agent-hooks/\n')
        result = self.run_prune('--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('.orca', self.source.read_text())
        self.assertIn('remove codex Stop', result.stdout)
