"""Keep the Hyper localization gate in the standard repository test command."""
from pathlib import Path
import subprocess
import sys
import unittest


class HyperI18nTest(unittest.TestCase):
    def test_catalog_source_coverage_and_generated_adapters(self):
        root = Path(__file__).resolve().parents[1]
        result = subprocess.run([sys.executable, '-B', 'config/hyper/generate.py', '--check'],
                                cwd=root, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
