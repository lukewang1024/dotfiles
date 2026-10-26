"""Real file access and privilege rejection for the scoped ncurses fallback."""
import ctypes
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CC = shutil.which('cc') or shutil.which('clang')


@unittest.skipUnless(os.name == 'posix' and CC, 'POSIX compiler required')
class NcursesCompatTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        mock = self.root / 'ids.c'
        mock.write_text('''
static unsigned int elevated;
void test_elevated(unsigned int value) { elevated = value; }
unsigned int test_getuid(void) { return 1000; }
unsigned int test_geteuid(void) { return elevated ? 0 : 1000; }
unsigned int test_getgid(void) { return 1000; }
unsigned int test_getegid(void) { return elevated ? 0 : 1000; }
''')
        library = self.root / 'compat.so'
        subprocess.run([CC, '-shared', '-fPIC', '-O2',
                        '-Dgetuid=test_getuid', '-Dgeteuid=test_geteuid',
                        '-Dgetgid=test_getgid', '-Dgetegid=test_getegid',
                        str(ROOT / 'util/ish/ncurses-compat.c'), str(mock),
                        '-o', str(library)], check=True, capture_output=True)
        self.lib = ctypes.CDLL(str(library), use_errno=True)
        self.open = self.lib._nc_safe_open3
        self.open.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_uint]
        self.fopen = self.lib._nc_safe_fopen
        self.fopen.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
        self.fopen.restype = ctypes.c_void_p
        self.libc = ctypes.CDLL(None)
        self.libc.fclose.argtypes = [ctypes.c_void_p]
        self.file = self.root / 'terminfo'
        self.file.write_bytes(b'actual terminal data')

    def test_open_and_fopen_preserve_real_file_access(self):
        fd = self.open(os.fsencode(self.file), os.O_RDONLY, 0)
        self.assertGreaterEqual(fd, 0)
        try:
            self.assertEqual(os.read(fd, 100), self.file.read_bytes())
        finally:
            os.close(fd)
        stream = self.fopen(os.fsencode(self.file), b'rb')
        self.assertTrue(stream)
        self.libc.fclose(stream)
        self.assertEqual(self.open(os.fsencode(self.root / 'absent'), os.O_RDONLY, 0), -1)

    def test_elevated_process_cannot_read_or_truncate(self):
        self.lib.test_elevated(1)
        self.assertEqual(self.open(os.fsencode(self.file), os.O_WRONLY | os.O_TRUNC, 0), -1)
        self.assertFalse(self.fopen(os.fsencode(self.file), b'w'))
        self.assertEqual(self.file.read_bytes(), b'actual terminal data')
