"""Recover reload delivery even when the palette link is already correct."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'util/termux/termux-system-theme'


class TermuxSystemThemeTests(unittest.TestCase):
    def test_retry_unchanged_palette_after_missed_reload(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.termux').mkdir()
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            palette = root / 'theme-dark.properties'
            palette.write_text('background=#1e1e2e\n')
            target = root / '.termux/colors.properties'
            target.symlink_to(palette)
            am = bin_dir / 'am'
            am.write_text('#!/bin/sh\nprintf "config: port-night-finger\\n"\n')
            am.chmod(0o755)
            reload = bin_dir / 'termux-reload-settings'
            reload.write_text('#!/bin/sh\nprintf "reload\\n" >> "$HOME/reloads"\nexit 1\n')
            reload.chmod(0o755)
            relay = bin_dir / 'theme-push-remotes'
            relay.write_text('#!/bin/sh\nprintf \"%s\\n\" \"$1\" >> \"$HOME/pushes\"\n')
            relay.chmod(0o755)
            fallback = bin_dir / 'tmux-appearance-fallback'
            fallback.write_text(
                '#!/bin/sh\nprintf "%s %s\\n" "$1" "$2" >> "$HOME/local-syncs"\n')
            fallback.chmod(0o755)
            env = dict(os.environ, HOME=str(root), PREFIX=str(root),
                       TERMUX_THEME_DIR=str(root), TERMUX_THEME_AM=str(am))
            for _ in range(2):
                subprocess.run(['sh', str(SCRIPT), '--once'], env=env, check=True)
            self.assertEqual((root / 'reloads').read_text(), 'reload\nreload\n')
            self.assertEqual(target.resolve(), palette.resolve())
            self.assertEqual((root / 'pushes').read_text(), 'dark\ndark\n')
            self.assertEqual((root / 'local-syncs').read_text(), 'dark all\ndark all\n')


if __name__ == '__main__':
    unittest.main()
