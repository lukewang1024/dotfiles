"""Scene defaults preserve machine-local config and retire old profiles."""
import importlib.util
from pathlib import Path
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('codex_profiles', ROOT / 'util/agent/codex-profiles-apply.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

class CodexProfileTests(unittest.TestCase):
    def test_scene_migration_preserves_local_settings_and_archives_profiles(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = root / 'codex'; runtime.mkdir()
            config = runtime / 'config.toml'
            config.write_text('model = "old"\n# keep comment\n[projects."/repo"]\ntrust_level = "trusted"\n[agents]\nenabled = true\nmax_concurrent_threads_per_session = 2\n')
            old = runtime / 'team-budget.config.toml'; old.write_text('model = "old-team"\n')
            scene = {'model':'gpt-6.1-sol', 'effort':'max', 'fast':True}
            archive = root / 'archive'
            MODULE.apply_profiles(root, runtime, scene, archive)
            parsed = tomllib.loads(config.read_text())
            self.assertEqual(parsed['model'], scene['model'])
            self.assertEqual(parsed['service_tier'], 'fast')
            self.assertFalse(parsed['agents']['enabled'])
            self.assertEqual(parsed['agents']['max_concurrent_threads_per_session'], 2)
            self.assertEqual(parsed['projects']['/repo']['trust_level'], 'trusted')
            self.assertIn('# keep comment', config.read_text())
            self.assertFalse(old.exists())
            self.assertEqual((archive / old.name).read_text(), 'model = "old-team"\n')
            before = config.read_bytes()
            MODULE.apply_profiles(root, runtime, scene, archive)
            self.assertEqual(config.read_bytes(), before)

    def test_empty_config_and_missing_agents_table_are_valid(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            MODULE.apply_profiles(root, root / 'codex', {'model':'chosen','effort':'max','fast':False}, root / 'archive')
            parsed = tomllib.loads((root / 'codex/config.toml').read_text())
            self.assertEqual(parsed['service_tier'], 'default')
            self.assertFalse(parsed['agents']['enabled'])
