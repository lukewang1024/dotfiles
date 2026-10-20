import importlib.machinery
import os
from pathlib import Path
import tempfile
import time
import unittest


module = importlib.machinery.SourceFileLoader(
    'storage_maintain', str(Path(__file__).parents[1] / 'util/macos/storage-maintain')
).load_module()


class CloneProtectionTests(unittest.TestCase):
    def test_protects_open_fresh_retained_and_symlinked_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            clone = root / 'code_sign_clone.test'
            clone.mkdir()
            leaf = clone / 'executable'
            leaf.write_text('test')
            old = time.time() - 10 * 86400
            for path in (clone, leaf):
                os.utime(path, (old, old))
            cutoff = time.time() - 86400
            self.assertTrue(module.eligible(clone, root, cutoff, set(), set()))
            self.assertFalse(module.eligible(clone, root, cutoff, {str(leaf)}, set()))
            self.assertFalse(module.eligible(clone, root, cutoff, set(), {clone}))
            link = root / 'code_sign_clone.link'
            link.symlink_to(clone)
            self.assertFalse(module.eligible(link, root, cutoff, set(), set()))
            os.utime(leaf, None)
            self.assertFalse(module.eligible(clone, root, cutoff, set(), set()))
