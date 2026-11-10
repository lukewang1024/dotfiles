"""Exercise the installed window-unlink hook on a private tmux server."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import unittest


TMUX = shutil.which("tmux")
CONFIG = Path(__file__).resolve().parents[1] / "config/tmux"


@unittest.skipUnless(TMUX, "tmux is not installed")
class WindowRenumberTests(unittest.TestCase):
    def setUp(self):
        # Exercise shell quoting for both the socket and the configuration path.
        self.temp = tempfile.TemporaryDirectory(prefix="tmux 'renumber- ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.socket = str(self.root / "socket")
        self.marker = self.root / "hook-complete"
        config = self.root / "config"
        config.mkdir()
        (config / "tmux").symlink_to(CONFIG, target_is_directory=True)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith("TMUX")}
        self.env.update(XDG_CONFIG_HOME=str(config), RENUMBER_TEST_MARKER=str(self.marker))
        self.addCleanup(self.tmux, "kill-server", check=False)

        self.tmux("new-session", "-d", "-s", "source", "-n", "first", "sleep", "300")
        self.tmux("set-option", "-g", "base-index", "1")
        self.tmux("set-option", "-g", "renumber-windows", "on")
        self.tmux("move-window", "-r", "-t", "source:")
        self.tmux("new-window", "-d", "-t", "source:", "-n", "second", "sleep", "300")
        self.tmux("new-window", "-d", "-t", "source:", "-n", "third", "sleep", "300")
        self.tmux("new-session", "-d", "-s", "destination", "-n", "existing", "sleep", "300")

        # Load the actual hook, without launching the other user plugins.
        config_text = (CONFIG / "tmux.conf").read_text()
        hook = re.search(r"(?ms)^set-hook -g 'window-unlinked\[90\]' \{\n.*?^\}", config_text)
        self.assertIsNotNone(hook, "the window-unlinked hook is missing")
        self.hook_file = self.root / "hook.conf"
        self.hook_file.write_text(hook.group() + "\n")
        self.tmux("source-file", str(self.hook_file))
        # The later hook marks completion after the asynchronous helper exits.
        self.tmux("set-hook", "-g", "window-unlinked[91]",
                  'run-shell \'touch "$RENUMBER_TEST_MARKER"\'')

    def tmux(self, *args, check=True):
        result = subprocess.run([TMUX, "-S", self.socket, "-f", "/dev/null", *args],
                                env=self.env, text=True, capture_output=True, timeout=10)
        if check and result.returncode:
            self.fail(f"tmux {args!r}: {result.stderr}")
        return result.stdout.strip()

    def windows(self, session="source"):
        output = self.tmux("list-windows", "-t", session, "-F",
                           "#{window_index} #{window_id} #{window_name} #{pane_id} #{pane_pid}")
        return [line.split() for line in output.splitlines()]

    def move_and_wait(self, source, destination):
        self.marker.unlink(missing_ok=True)
        self.tmux("move-window", "-s", source, "-t", destination)
        deadline = time.monotonic() + 5
        while not self.marker.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertTrue(self.marker.exists(), "window-unlinked hook did not finish")

    def test_cross_session_move_compacts_and_preserves_window_and_pane_identity(self):
        before = self.windows()
        self.move_and_wait("source:1", "destination:")
        after = self.windows()
        self.assertEqual([row[0] for row in after], ["1", "2"])
        self.assertEqual([row[1:] for row in after], [row[1:] for row in before[1:]])
        moved = self.windows("destination")[-1]
        self.assertEqual(moved[1:], before[0][1:])

    def test_source_session_can_disable_renumbering(self):
        self.tmux("set-option", "-t", "source", "renumber-windows", "off")
        self.move_and_wait("source:1", "destination:")
        self.assertEqual([row[0] for row in self.windows()], ["2", "3"])

    def test_same_session_move_keeps_the_explicit_index(self):
        self.move_and_wait("source:1", "source:5")
        self.assertEqual([(row[0], row[2]) for row in self.windows()],
                         [("2", "second"), ("3", "third"), ("5", "first")])

    def test_session_base_index_is_respected(self):
        self.tmux("set-option", "-t", "source", "base-index", "4")
        self.tmux("move-window", "-r", "-t", "source:")
        self.move_and_wait("source:4", "destination:")
        self.assertEqual([row[0] for row in self.windows()], ["4", "5"])

    def test_config_path_falls_back_to_home_when_xdg_is_unset(self):
        home = self.root / "home"
        (home / ".config").mkdir(parents=True)
        (home / ".config/tmux").symlink_to(CONFIG, target_is_directory=True)
        self.tmux("set-environment", "-gu", "XDG_CONFIG_HOME")
        self.tmux("set-environment", "-g", "HOME", str(home))
        self.move_and_wait("source:1", "destination:")
        self.assertEqual([row[0] for row in self.windows()], ["1", "2"])

    def test_moving_last_window_allows_source_session_to_disappear(self):
        self.tmux("new-session", "-d", "-s", "single", "-n", "only", "sleep", "300")
        self.move_and_wait("single:1", "destination:")
        self.assertEqual([row[2] for row in self.windows("destination")], ["existing", "only"])

    def test_reload_does_not_add_another_copy_of_the_hook(self):
        self.tmux("source-file", str(self.hook_file))
        hooks = self.tmux("show-hooks", "-g", "window-unlinked").splitlines()
        self.assertEqual(sum(line.startswith("window-unlinked[90]") for line in hooks), 1)


if __name__ == "__main__":
    unittest.main()
