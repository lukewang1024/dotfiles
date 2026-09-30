"""Known ignored settings are cleaned without changing unrelated local state."""
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    'codex_config_clean', ROOT / 'util/agent/codex-config-clean.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CodexConfigCleanTests(unittest.TestCase):
    def test_cleanup_preserves_supported_settings_and_is_idempotent(self):
        before = '''# Keep local defaults
review_model = "local-review"
sandbox_mode = "workspace-write"
[profiles."spec-review"] # local profile
model = "local"
review_model = "ignored"
sandbox_mode = "read-only"
[projects."/local/project"]
trust_level = "trusted"
sandbox_mode = "danger-full-access"
[mcp_servers.local]
command = "local-tool"
'''
        expected = before.replace('review_model = "ignored"\n', '').replace(
            'sandbox_mode = "danger-full-access"\n', '')
        self.assertEqual(MODULE.clean_config(before), expected)
        self.assertEqual(MODULE.clean_config(expected), expected)

    def test_multiline_values_and_quoted_keys(self):
        before = '''[profiles.review]
developer_instructions = """
[projects."not-a-table"]
sandbox_mode = "keep this text"
"""
"review_model" = """ignored
value"""
'''
        self.assertEqual(MODULE.clean_config(before), before.split('"review_model" =')[0])

    def test_inline_layout_fails_without_silently_changing_other_settings(self):
        with self.assertRaisesRegex(ValueError, 'TOML layout'):
            MODULE.clean_config('profiles = { review = { model = "keep", review_model = "ignored" } }\n')

    def test_shared_templates_do_not_seed_ignored_settings(self):
        for path in (ROOT / 'config/agent').glob('*.toml'):
            text = path.read_text()
            self.assertEqual(MODULE.clean_config(text), text, path)
