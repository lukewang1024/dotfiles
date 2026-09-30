import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CodexTuiSettingsTests(unittest.TestCase):
    def test_apply_seeds_and_migrates_alternate_screen_idempotently(self):
        for existing in ('', '[tui]\nalternate_screen = "always"\nraw_output_mode = false\n'):
            with self.subTest(existing=existing), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                config = home / 'config.toml'
                config.write_text('model = "local-model"\n' + existing)
                env = dict(os.environ, CODEX_HOME=directory)
                previous = None
                for _ in range(2):
                    result = subprocess.run(
                        ['/bin/sh', str(ROOT / 'util/agent/codex-settings-apply')],
                        env=env, text=True, capture_output=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    contents = config.read_text()
                    values = tomllib.loads(contents)
                    self.assertEqual(values['model'], 'local-model')
                    self.assertEqual(values['tui']['alternate_screen'], 'never')
                    if existing:
                        self.assertIs(values['tui']['raw_output_mode'], False)
                    else:
                        self.assertNotIn('raw_output_mode', values['tui'])
                    if previous is not None:
                        self.assertEqual(contents, previous)
                    previous = contents
