"""Codex-writable profiles must never write machine state into shared templates."""
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
    def test_seed_migrate_and_repeat_preserve_local_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            templates, runtime = root / 'templates', root / 'codex'
            templates.mkdir()
            runtime.mkdir()
            for name in ('team.config.toml', 'team-budget.config.toml'):
                (templates / name).write_text('model = "shared"\n')
            source = templates / 'team-budget.config.toml'
            trust = '\n[projects."/local/project"]\ntrust_level = "trusted"\n'
            source.write_text(source.read_text() + trust)
            target = runtime / source.name
            target.symlink_to(source)
            MODULE.apply_profiles(templates, runtime)
            self.assertFalse(target.is_symlink())
            self.assertEqual(target.read_bytes(), source.read_bytes())
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            source.write_text('model = "new-template"\n')
            target.write_text(target.read_text() + '\n[notice]\nhide_warning = true\n')
            before = target.read_bytes()
            MODULE.apply_profiles(templates, runtime)
            self.assertEqual(target.read_bytes(), before)
            self.assertEqual(tomllib.loads(target.read_text())['projects']['/local/project']['trust_level'], 'trusted')
            self.assertNotIn('projects', tomllib.loads(source.read_text()))
            self.assertFalse((runtime / 'team.config.toml').is_symlink())

    def test_unrelated_symlink_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'other.toml'
            source.write_text('model = "local"\n')
            target = root / 'team.config.toml'
            target.symlink_to(source)
            with self.assertRaisesRegex(RuntimeError, 'unrelated'):
                MODULE.apply_profiles(root / 'templates', root)
            self.assertTrue(target.is_symlink())
            self.assertEqual(source.read_text(), 'model = "local"\n')

    def test_shared_templates_contain_no_project_state(self):
        for name in ('team.config.toml', 'team-budget.config.toml'):
            self.assertNotIn('projects', tomllib.loads((ROOT / 'config/agent' / name).read_text()))
