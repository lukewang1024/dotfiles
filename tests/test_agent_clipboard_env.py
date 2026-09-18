import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "config/zsh/agent-resume-history.zsh"


@unittest.skipUnless(shutil.which("zsh"), "zsh is required")
class AgentClipboardEnvTest(unittest.TestCase):
    def launch(self, contents, disabled=False):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "clipboard-env"
            sentinel = Path(directory) / "executed"
            if contents is not None:
                config.write_text(contents.replace("SENTINEL", str(sentinel)))
            env = dict(os.environ, DISPLAY="original", XAUTHORITY="original-auth",
                       WAYLAND_DISPLAY="original-wayland",
                       AGENT_CLIPBOARD_ENV_FILE="" if disabled else str(config))
            # No CLI is needed; the child executable is supplied by absolute path.
            env["PATH"] = directory
            probe = (
                "import os,json,sys; print(json.dumps(["
                "[os.getenv(k) for k in ('DISPLAY','XAUTHORITY','WAYLAND_DISPLAY')],"
                "sys.argv[1:],sys.stdin.read()])); sys.exit(37)"
            )
            result = subprocess.run(
                [shutil.which("zsh"), "-f", "-c",
                 'source "$1"; _agent_exec_with_clipboard_env "$2" -c "$3" "arg with spaces"; '
                 'result=$?; print -r -- "$result|$DISPLAY|$XAUTHORITY|$WAYLAND_DISPLAY"',
                 "test", str(SCRIPT), sys.executable, probe],
                env=env, input="input preserved", text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            child, parent = result.stdout.splitlines()
            values, args, stdin = json.loads(child)
            self.assertEqual(args, ["arg with spaces"])
            self.assertEqual(stdin, "input preserved")
            self.assertEqual(parent, "37|original|original-auth|original-wayland")
            self.assertFalse(sentinel.exists())
            return values

    def test_valid_environment_without_cli(self):
        self.assertEqual(self.launch("DISPLAY=:97\nXAUTHORITY=/path with spaces/auth"),
                         [":97", "/path with spaces/auth", None])

    def test_missing_invalid_or_disabled_preserves_environment(self):
        for contents in (None, "DISPLAY=:97\n", "DISPLAY=\nXAUTHORITY=/auth\n",
                         "DISPLAY=:97\nXAUTHORITY=/auth\nPATH=/bad\n"):
            with self.subTest(contents=contents):
                self.assertEqual(self.launch(contents),
                                 ["original", "original-auth", "original-wayland"])
        self.assertEqual(self.launch("DISPLAY=:97\nXAUTHORITY=/auth", disabled=True),
                         ["original", "original-auth", "original-wayland"])

    def test_values_are_literal(self):
        values = self.launch("DISPLAY=:97\nXAUTHORITY=$(touch SENTINEL)\n")
        self.assertTrue(values[1].startswith("$(touch "))


if __name__ == "__main__":
    unittest.main()
