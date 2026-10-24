"""Exercise the native fchmodat fallback against real sandbox files."""
import ctypes
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMPILER = shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')


@unittest.skipUnless(sys.platform in ('linux', 'android') and COMPILER, 'Linux C compiler required')
class APKCompatTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.build.cleanup)
        library = Path(cls.build.name) / 'compat.so'
        subprocess.run([COMPILER, '-shared', '-fPIC', '-O2', str(ROOT / 'util/ish/apk-compat.c'),
                        '-o', str(library)], check=True, capture_output=True)
        cls.library = ctypes.CDLL(str(library), use_errno=True)
        cls.chmod = cls.library.fchmodat
        cls.chmod.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint, ctypes.c_int]

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.file = self.root / 'file'
        self.file.write_text('sandbox\n')

    def test_permissions_apply_to_file_and_directory(self):
        for path, mode in ((self.file, 0o640), (self.root, 0o750)):
            self.assertEqual(self.chmod(-100, os.fsencode(path), mode, 0x100), 0)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), mode)

    def test_no_follow_rejects_symlink_without_changing_target(self):
        self.file.chmod(0o640)
        link = self.root / 'link'
        link.symlink_to(self.file)
        self.assertEqual(self.chmod(-100, os.fsencode(link), 0o600, 0x100), -1)
        self.assertEqual(stat.S_IMODE(self.file.stat().st_mode), 0o640)
        self.assertTrue(link.is_symlink())

    def test_relative_directory_fd_and_invalid_flags(self):
        fd = os.open(self.root, os.O_RDONLY)
        self.addCleanup(os.close, fd)
        self.assertEqual(self.chmod(fd, b'file', 0o600, 0x100), 0)
        self.assertEqual(stat.S_IMODE(self.file.stat().st_mode), 0o600)
        self.assertEqual(self.chmod(fd, b'file', 0o777, 0x400000), -1)
        self.assertEqual(stat.S_IMODE(self.file.stat().st_mode), 0o600)
