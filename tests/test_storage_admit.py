import importlib.machinery
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest import mock

loader = importlib.machinery.SourceFileLoader(
    'storage_admit', str(Path(__file__).parents[1] / 'util/shell/storage-admit')
)
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class AdmissionTests(unittest.TestCase):
    def test_read_only_capacity_query_and_configurable_reserve(self):
        with mock.patch.object(module.shutil, 'disk_usage', return_value=SimpleNamespace(free=12 * module.GIB)):
            self.assertTrue(module.check(Path('/'), 8, 4)['admitted'])
            self.assertFalse(module.check(Path('/'), 8, 5)['admitted'])

    def test_low_capacity_never_launches_command(self):
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.dict(module.os.environ, {'XDG_STATE_HOME': directory}), \
                    mock.patch.object(module.shutil, 'disk_usage', return_value=SimpleNamespace(free=module.GIB)), \
                    mock.patch('sys.argv', ['storage-admit', '--working-gib', '32', '--', 'must-not-run']), \
                    mock.patch.object(module.subprocess, 'run') as run:
                self.assertEqual(module.main(), 2)
                run.assert_not_called()
