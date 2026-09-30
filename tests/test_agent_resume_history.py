import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import sys


SCRIPT = Path(__file__).resolve().parents[1] / "config/zsh/agent-resume-history.zsh"


@unittest.skipUnless(shutil.which("zsh") and shutil.which("jq"), "zsh and jq are required")
class AgentResumeHistoryTest(unittest.TestCase):
    def test_codex_shortcuts_capture_output_and_preserve_command_name(self):
        session = "01a0f092-a417-7d91-8d46-32ce516fed67"
        for command in ["codex-yolo", "codex-team", "codex-team-budget", "codex-team-expert"]:
            with self.subTest(command=command), tempfile.TemporaryDirectory() as directory:
                child = Path(directory) / command
                child.write_text(f'#!/bin/sh\nprintf "Session ID: {session}\\n"\n')
                child.chmod(0o755)
                result = subprocess.run([
                    shutil.which("zsh"), "-f", "-c",
                    'source "$1"; _test_executable="$2/$3"; '
                    '_agent_exec_with_clipboard_env() { '
                    'local -a args; args=("$@"); args[4]=$_test_executable; command "${args[@]}"; }; '
                    '_agent_add_history() { print -r -- "HISTORY:$1"; }; "$3"',
                    "test", str(SCRIPT), directory, command,
                ], stdin=subprocess.DEVNULL, text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"HISTORY:{command} resume {session}", result.stdout)

    def test_codex_remembers_its_exit_hint_instead_of_background_rollout(self):
        correct = "01a0f084-47b9-7e00-9e1f-2d144b004fb3"
        for hint in [
            f"To continue this session, run:\n  codex resume {correct}\n",
            f"Disconnected from this task. Any running work continues.\n"
            f"To reconnect, run:\n  \x1b[32mcodex resume {correct}\x1b[0m\n"
            "Stop the current turn: run codex agents, select this task, and press x.\n",
            f"Session ID: {correct}\n",
            f"TUI screen without newline\x1b[?1049l\x1b[?25hSession ID: {correct}\r\n",
            "No session selected.\n",
        ]:
            with self.subTest(hint=hint), tempfile.TemporaryDirectory() as directory:
                child = Path(directory) / "child.py"
                child.write_text(
                    "import os,sys\nassert os.isatty(0) and os.isatty(1)\n"
                    f"print({hint!r})\nsys.exit(37)\n"
                )
                result = subprocess.run([
                    shutil.which("zsh"), "-f", "-c",
                    'source "$1"; '
                    '_agent_session_id_from_jsonl() { print WRONG-BACKGROUND-SESSION; }; '
                    '_agent_add_history() { print -r -- "HISTORY:$1"; }; '
                    '_agent_run_and_remember codex "$2" "codex resume" "$4/sessions" "$3"; '
                    'print -r -- "EXIT:$?"',
                    "test", str(SCRIPT), sys.executable, str(child), directory,
                ], stdin=subprocess.DEVNULL, text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("EXIT:37", result.stdout)
                self.assertNotIn("WRONG-BACKGROUND-SESSION", result.stdout)
                if correct in hint:
                    self.assertIn(f"HISTORY:codex resume {correct}", result.stdout)
                else:
                    self.assertNotIn("HISTORY:", result.stdout)

    def test_output_is_remembered_without_persisted_session(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([
                shutil.which("zsh"), "-f", "-c",
                'source "$1"; _agent_add_history() { print "HISTORY:$1"; }; '
                '_agent_run_and_remember codex "$2" "codex resume" "$3/sessions" '
                '-c "$4"; '
                'print "EXIT:$?"',
                "test", str(SCRIPT), sys.executable, directory,
                'print("Session ID: 01a0f088-7a03-7ae1-af97-95fbfccf22e9")',
            ], stdin=subprocess.DEVNULL, text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("EXIT:0", result.stdout)
            self.assertIn(
                "HISTORY:codex resume 01a0f088-7a03-7ae1-af97-95fbfccf22e9",
                result.stdout,
            )

    def test_resume_uses_updated_session_through_directory_alias(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            cwd = base / "actual"
            cwd.mkdir()
            alias = base / "alias"
            alias.symlink_to(cwd, target_is_directory=True)
            root = base / "sessions"
            root.mkdir()
            marker = base / "marker"
            marker.touch()
            os.utime(marker, (100, 100))
            for name, location, timestamp in [
                ("resumed", cwd, 200), ("unrelated", base, 300),
                ("old", cwd, 50), ("missing-cwd", None, 400),
            ]:
                rollout = root / f"rollout-{name}.jsonl"
                rollout.write_text(json.dumps({"payload": {
                    "id": name, "cwd": str(location) if location else None,
                }}) + "\n")
                os.utime(rollout, (timestamp, timestamp))
            result = subprocess.run([
                shutil.which("zsh"), "-f", "-c",
                'source "$1"; _agent_session_id_from_jsonl "$2" "$3" "$4"',
                "test", str(SCRIPT), str(root), str(marker), str(alias),
            ], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "resumed")

    def test_codex_home_and_history_prefix(self):
        result = subprocess.run([
            shutil.which("zsh"), "-f", "-c",
            'source "$1"; CODEX_HOME="/tmp/custom codex"; '
            '_agent_run_and_remember() { printf "%s\\n" "$@"; }; '
            '_agent_codex_run /fake/codex codex-budget --yolo resume --last',
            "test", str(SCRIPT),
        ], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "codex", "/fake/codex", "codex-budget --yolo resume",
            "/tmp/custom codex/sessions", "--yolo", "resume", "--last",
        ])


if __name__ == "__main__":
    unittest.main()
