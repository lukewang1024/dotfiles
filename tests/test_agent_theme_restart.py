import importlib.util
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "agent_theme_restart", ROOT / "config/zsh/agent_theme_restart.py"
)
theme = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(theme)


def title(value):
    return f"\x1b]0;codex | {value} | 01a12a2b-3287-7bf2-8fc1-661e52ea78b1\x07".encode()


class RestartGateTest(unittest.TestCase):
    def test_waits_for_explicit_ready_and_never_uses_silence(self):
        gate = theme.RestartGate(0)
        self.assertFalse(gate.can_quit(100))
        gate.output(title("Thinking"), 0)
        self.assertFalse(gate.can_quit(100))
        gate.output(title("Ready")[:7], 1)
        gate.output(title("Ready")[7:], 1)
        self.assertFalse(gate.can_quit(2))
        self.assertTrue(gate.can_quit(3))
        gate.output(title("Working"), 4)
        self.assertFalse(gate.can_quit(100))

    def test_draft_is_protected_until_actual_submission(self):
        gate = theme.RestartGate(0)
        gate.output(title("Working"), 0)
        gate.output(title("Ready"), 0)
        gate.input(b"draft\r", 3)
        self.assertFalse(gate.can_quit(100))
        # Enter alone might have inserted a newline or selected a popup.
        gate.output(title("Ready"), 4)
        self.assertFalse(gate.can_quit(100))
        gate.output(title("Thinking"), 5)
        gate.output(title("Ready"), 6)
        self.assertTrue(gate.can_quit(8))
        gate.input(b"another draft", 9)
        self.assertFalse(gate.can_quit(100))

    def test_real_busy_titles_with_spinner_confirm_submission(self):
        for agent, app in (("codex", "codex"), ("traex", "traecli")):
            with self.subTest(agent=agent):
                gate = theme.RestartGate(0, agent)
                gate.input(b"prompt\r", 1)
                gate.output(f"\x1b]0;{app} | Working ⠼ 01a12a2b-3287-7bf2-8fc1-661e5...\x07".encode(), 2)
                self.assertFalse(gate.dirty)
                self.assertFalse(gate.submitted)
                gate.output(f"\x1b]0;{app} | Ready | 01a12a2b-3287-7bf2-8fc1-661e5...\x07".encode(), 3)
                self.assertTrue(gate.can_quit(5))

    def test_empty_composer_probe_still_requires_idle_and_stops_during_paste(self):
        gate = theme.RestartGate(0)
        gate.input(b"\x0c", 1)  # Ctrl+L may refresh the screen without adding text.
        gate.output(title("Working"), 2)
        self.assertFalse(gate.can_quit(100, probe_empty=True))
        gate.output(title("Ready"), 3)
        self.assertFalse(gate.can_quit(5))
        self.assertTrue(gate.can_quit(5, probe_empty=True))
        gate.input(b"\x1b[200~draft", 6)
        self.assertFalse(gate.can_quit(100, probe_empty=True))

    def test_new_typing_after_submit_stays_protected(self):
        gate = theme.RestartGate(0)
        gate.input(b"prompt\rnext", 1)
        gate.output(title("Working"), 2)
        gate.output(title("Ready"), 3)
        self.assertFalse(gate.can_quit(100))

    def test_pasted_newlines_and_history_keys_do_not_clear_draft(self):
        for data in (b"\x1b[200~hello\rworld\x1b[201~", b"\x1b[A", b"\x1b[13;2u"):
            gate = theme.RestartGate(0)
            gate.input(data, 1)
            gate.output(title("Working"), 2)
            gate.output(title("Ready"), 3)
            self.assertFalse(gate.can_quit(100))

    def test_terminal_responses_and_enhanced_enter(self):
        gate = theme.RestartGate(0)
        gate.output(title("Working"), 0)
        gate.output(title("Ready"), 0)
        gate.input(b"\x1b]11;rgb:ffff/ffff/ffff\x1b\\\x1b[?1;2c\x1b[?0u\x1bP>|Termux\x1b\\", 1)
        self.assertTrue(gate.can_quit(3))
        gate.input(b"prompt\x1b[13u", 4)
        gate.input(b"\x1b[13;1:3u", 4)
        gate.output(title("Working"), 5)
        gate.output(title("Ready"), 6)
        self.assertTrue(gate.can_quit(8))

    def test_requires_attached_thread_and_accepts_actual_truncation(self):
        gate = theme.RestartGate(0)
        gate.seen_work = True
        gate.output(b"\x1b]0;codex | Ready\x07", 0)
        self.assertFalse(gate.can_quit(100))
        gate.output(b"\x1b]0;codex | Ready | 01a12a2b-3287-7bf2-8fc1-661e5...\x07", 1)
        self.assertTrue(gate.can_quit(3))
        self.assertEqual(gate.thread_prefix, "01a12a2b-3287-7bf2-8fc1-661e5")

    def test_action_required_and_unrecognized_titles_block_exit(self):
        gate = theme.RestartGate(0)
        gate.output(title("Working"), 0)
        gate.output(title("Ready"), 0)
        self.assertTrue(gate.can_quit(3))
        for data in (b"\x1b]2;! Codex\x07", title("Waiting"), b"\x1b]2;other app\x07"):
            gate.output(data, 4)
            self.assertFalse(gate.can_quit(100))

    def test_displayed_change_triggers_even_when_file_is_unchanged(self):
        gate = theme.RestartGate(0)
        palette = b"foreground=#cdd6f4\nbackground=#1e1e2e\n"
        gate.input(b"\x1b]10;rgb:4c4c/4f4f/6969\x07\x1b]11;rgb:efef/f1f1/f5f5\x07", 0)
        self.assertIsNone(gate.refresh_signature(palette, palette))
        gate.input(b"\x1b]10;rgb:cdcd/d6d6/f4f4\x07\x1b]11;rgb:1e1e/1e1e/2e2e\x07", 5)
        self.assertIsNotNone(gate.refresh_signature(palette, palette))
        self.assertFalse(gate.dirty)

    def test_file_change_waits_for_actual_terminal_reload(self):
        gate = theme.RestartGate(0)
        palette = b"foreground=#cdd6f4\nbackground=#1e1e2e\n"
        gate.input(b"\x1b]10;rgb:4c/4f/69\x07\x1b]11;rgb:ef/f1/f5\x07", 0)
        self.assertIsNone(gate.refresh_signature(palette, b"light"))
        gate.input(b"\x1b]10;rgb:cd/d6/f4\x07\x1b]11;rgb:1e/1e/2e\x07", 5)
        self.assertIsNotNone(gate.refresh_signature(palette, b"light"))

    def test_color_queries_do_not_delay_idle_or_hide_real_typing(self):
        gate = theme.RestartGate(0)
        gate.output(title("Working"), 0)
        gate.output(title("Ready"), 0)
        gate.input(b"\x1b]11;rgb:1e1e/1e1e/", 4)
        self.assertFalse(gate.can_quit(4))  # Incomplete escape reply.
        gate.input(b"2e2e\x1b\\", 5)
        self.assertTrue(gate.can_quit(5))
        gate.input(b"\x1b]11;rgb:1e/1e/2e\x07draft", 6)
        self.assertFalse(gate.can_quit(100))
        self.assertEqual(gate.last_input, 6)

    def test_terminal_only_refresh_works_without_android_or_palette_file(self):
        gate = theme.RestartGate(0)
        gate.input(b"\x1b]10;rgb:cd/d6/f4\x07\x1b]11;rgb:1e/1e/2e\x07", 0)
        self.assertIsNone(gate.refresh_signature(None, None))
        gate.input(b"\x1b]10;rgb:4c/4f/69\x07\x1b]11;rgb:ef/f1/f5\x07", 5)
        self.assertIsNotNone(gate.refresh_signature(None, None))
        with mock.patch.object(theme.os, "isatty", return_value=True), mock.patch.dict(theme.os.environ, {}, clear=True):
            self.assertTrue(theme.enabled(["codex"], "codex"))
            self.assertTrue(theme.enabled(["traex"], "traex"))
            self.assertFalse(theme.enabled(["claude"], "claude"))
            with mock.patch.dict(theme.os.environ, {"AGENT_THEME_RESTART": "0"}):
                self.assertFalse(theme.enabled(["traex"], "traex"))
            with mock.patch.dict(theme.os.environ, {"TRAEX_THEME_RESTART": "0"}):
                self.assertFalse(theme.enabled(["traex"], "traex"))
                self.assertTrue(theme.enabled(["codex"], "codex"))

    def test_traex_identity_waits_for_its_own_ready_thread(self):
        session = "01a12a2b-3287-7bf2-8fc1-661e52ea78b1"
        gate = theme.RestartGate(0, "traex")
        gate.output(title("Working"), 0)  # Other agent's title cannot authorize exit.
        gate.output(title("Ready"), 0)
        self.assertFalse(gate.can_quit(100))
        gate.output(b"\x1b]0;traecli | Working\x07", 1)
        gate.output(f"\x1b]0;traecli | Ready | {session}\x07".encode(), 2)
        self.assertTrue(gate.can_quit(4))
        gate.input(b"draft", 5)
        self.assertFalse(gate.can_quit(100))
        gate.output(b"\x1b]0;traecli | Waiting for response\x07", 6)
        self.assertFalse(gate.can_quit(100))

    def test_traex_options_preserve_permissions_and_tool_restrictions(self):
        args = ["traex", "-y", "--permission-mode", "auto", "--allowed-tool", "shell", "resume", "id"]
        self.assertEqual(theme.resume_options(args, "traex"), args[1:6])
        self.assertIsNone(theme.resume_options(args, "codex"))
        for command in ("acp", "mcp-server", "exec", "fork"):
            self.assertIsNone(theme.resume_options(["traex", command], "traex"))

    def test_relaunch_retains_settings_without_replaying_prompt(self):
        self.assertEqual(theme.resume_options([
            "codex-expert", "--yolo", "-p", "expert", "-C", "/repo with spaces",
            "--add-dir=/other", "resume", "--last", "initial prompt",
        ]), ["--yolo", "-p", "expert", "-C", "/repo with spaces", "--add-dir=/other"])
        for option in ("--no-daemon", "--worktree", "-i", "--unknown", "fork"):
            self.assertIsNone(theme.resume_options(["codex", option]))


@unittest.skipUnless(hasattr(os, "fork"), "PTY supervisor requires POSIX")
class SupervisorTest(unittest.TestCase):
    def test_real_pty_waits_for_completion_and_resumes_exact_id(self):
        self.check_pty_agent("codex")

    def test_traex_pty_waits_for_completion_and_resumes_exact_id(self):
        self.check_pty_agent("traex")

    def test_terminal_only_pty_refresh_without_a_palette_file(self):
        session = "01a12a2b-3287-7bf2-8fc1-661e52ea78b1"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            child = root / "traex"
            child.write_text(
                f"#!{sys.executable}\n"
                "import os,select,sys,time,tty\n"
                "tty.setraw(0)\n"
                "if 'resume' in sys.argv: print('RESUMED',flush=True);sys.exit(0)\n"
                "os.write(1,b'\\x1b]0;traex | Working\\x07')\n"
                "deadline=time.monotonic()+0.5\n"
                "while time.monotonic()<deadline:\n"
                " if select.select([0],[],[],0.05)[0] and b'\\x04' in os.read(0,4096):sys.exit(91)\n"
                f"os.write(1,b'DISPLAY_LIGHT\\x1b]0;traex | Ready | {session}\\x07')\n"
                "deadline=time.monotonic()+10\n"
                "while time.monotonic()<deadline:\n"
                " if select.select([0],[],[],0.1)[0] and b'\\x04' in os.read(0,4096):\n"
                f"  os.write(1,b'\\r\\ntraecli resume {session}\\r\\n');sys.exit(0)\n"
                "sys.exit(92)\n"
            )
            child.chmod(0o755)
            launcher = root / "launcher.py"
            launcher.write_text(
                "import sys,os,importlib.util\n"
                f"sys.path.insert(0,{str(ROOT / 'config/zsh')!r})\n"
                "import agent_theme_restart as t\n"
                f"s=importlib.util.spec_from_file_location('capture',{str(ROOT / 'config/zsh/agent-capture-session.py')!r})\n"
                "c=importlib.util.module_from_spec(s);s.loader.exec_module(c)\n"
                "t.palette_path=lambda:None\n"
                f"status,_=t.run([{str(child)!r}],lambda o:c.session_id(o,'traex'),'traex')\n"
                "sys.exit(os.waitstatus_to_exitcode(status))\n"
            )
            master, slave = pty.openpty()
            process = subprocess.Popen([sys.executable, str(launcher)], stdin=slave, stdout=slave, stderr=slave)
            os.close(slave)
            output = bytearray()
            pending = bytearray()
            light = False
            deadline = time.monotonic() + 14
            try:
                while time.monotonic() < deadline:
                    if select.select([master], [], [], 0.1)[0]:
                        try:
                            chunk = os.read(master, 65536)
                        except OSError:
                            break
                        output.extend(chunk)
                        pending.extend(chunk)
                        if b"DISPLAY_LIGHT" in output:
                            light = True
                        for code in (10, 11):
                            query = f"\x1b]{code};?\x07".encode()
                            while query in pending:
                                start = pending.index(query)
                                del pending[start:start + len(query)]
                                color = ("4c/4f/69" if code == 10 else "ef/f1/f5") if light else (
                                    "cd/d6/f4" if code == 10 else "1e/1e/2e"
                                )
                                os.write(master, f"\x1b]{code};rgb:{color}\x07".encode())
                        del pending[:-4096]
                    if process.poll() is not None:
                        break
                self.assertEqual(process.wait(timeout=2), 0, output.decode(errors="replace"))
                self.assertIn(b"RESUMED", output)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                os.close(master)

    def test_refused_probe_is_not_repeated_until_input_changes(self):
        session = "01a12a2b-3287-7bf2-8fc1-661e52ea78b1"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            palette = root / "colors.properties"
            palette.write_text("dark")
            child = root / "codex"
            child.write_text(
                f"#!{sys.executable}\n"
                "import os,select,sys,time,tty\nfrom pathlib import Path\n"
                "tty.setraw(0)\n"
                "if 'resume' in sys.argv: print('RESUMED',flush=True);sys.exit(0)\n"
                "os.write(1,b'\\x1b]0;codex | Working\\x07')\n"
                f"Path({str(palette)!r}).write_text('light')\n"
                f"os.write(1,b'\\x1b]0;codex | Ready | {session}\\x07')\n"
                "count=0;cleared=False;deadline=time.monotonic()+14\n"
                "while time.monotonic()<deadline:\n"
                " if not select.select([0],[],[],0.1)[0]:continue\n"
                " data=os.read(0,4096)\n"
                " if b'\\x15' in data:cleared=True\n"
                " if b'\\x04' in data:\n"
                "  count+=1\n"
                "  if count==1:os.write(1,b'REFUSED');continue\n"
                "  if not cleared:sys.exit(94)\n"
                f"  os.write(1,b'\\r\\nSession ID: {session}\\r\\n');sys.exit(0)\n"
                "sys.exit(92)\n"
            )
            child.chmod(0o755)
            launcher = root / "launcher.py"
            launcher.write_text(
                "import sys,os,importlib.util\nfrom pathlib import Path\n"
                f"sys.path.insert(0,{str(ROOT / 'config/zsh')!r})\n"
                "import agent_theme_restart as t\n"
                f"s=importlib.util.spec_from_file_location('capture',{str(ROOT / 'config/zsh/agent-capture-session.py')!r})\n"
                "c=importlib.util.module_from_spec(s);s.loader.exec_module(c)\n"
                f"t.palette_path=lambda:Path({str(palette)!r})\n"
                f"status,_=t.run([{str(child)!r}],c.session_id)\n"
                "sys.exit(os.waitstatus_to_exitcode(status))\n"
            )
            master, slave = pty.openpty()
            process = subprocess.Popen([sys.executable, str(launcher)], stdin=slave, stdout=slave, stderr=slave)
            os.close(slave)
            output = bytearray()
            refused_at = None
            cleared = False
            deadline = time.monotonic() + 18
            try:
                while time.monotonic() < deadline:
                    if select.select([master], [], [], 0.1)[0]:
                        try:
                            output.extend(os.read(master, 65536))
                        except OSError:
                            break
                    if refused_at is None and b"REFUSED" in output:
                        refused_at = time.monotonic()
                    if refused_at is not None and not cleared and time.monotonic() - refused_at > 4:
                        os.write(master, b"\x15")  # Simulate clearing the restored draft.
                        cleared = True
                    if process.poll() is not None:
                        break
                self.assertEqual(process.wait(timeout=2), 0, output.decode(errors="replace"))
                self.assertTrue(cleared)
                self.assertIn(b"RESUMED", output)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                os.close(master)

    def check_pty_agent(self, agent):
        session = "01a12a2b-3287-7bf2-8fc1-661e52ea78b1"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            palette = root / "colors.properties"
            palette.write_text("dark")
            commands = root / "commands"
            child = root / agent
            child.write_text(
                f"#!{sys.executable}\n"
                "import json,os,select,sys,time,tty\n"
                "from pathlib import Path\n"
                "tty.setraw(0)\n"
                f"with Path({str(commands)!r}).open('a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')\n"
                "if 'resume' in sys.argv:\n"
                " print('RESUMED',flush=True); sys.exit(0)\n"
                f"os.write(1,b'\\x1b]0;{agent} | Working\\x07')\n"
                f"Path({str(palette)!r}).write_text('light')\n"
                "if select.select([0],[],[],0.4)[0]: sys.exit(91)\n"
                f"os.write(1,b'\\x1b]0;{agent} | Ready | {session}\\x07')\n"
                "if not select.select([0],[],[],5)[0]: sys.exit(92)\n"
                "if os.read(0,1)!=b'\\x04': sys.exit(93)\n"
                f"os.write(1,b'\\r\\nSession ID: {session}\\r\\n')\n"
            )
            child.chmod(0o755)
            launcher = root / "launcher.py"
            launcher.write_text(
                "import sys\nfrom pathlib import Path\n"
                f"sys.path.insert(0,{str(ROOT / 'config/zsh')!r})\n"
                "import agent_theme_restart as t\n"
                "import importlib.util\n"
                f"s=importlib.util.spec_from_file_location('capture',{str(ROOT / 'config/zsh/agent-capture-session.py')!r})\n"
                "c=importlib.util.module_from_spec(s);s.loader.exec_module(c)\n"
                f"t.palette_path=lambda: Path({str(palette)!r})\n"
                f"p=Path({directory!r})/'.termux';p.mkdir();(p/'colors.properties').symlink_to({str(palette)!r})\n"
                f"status,output=t.run([{str(child)!r},'--yolo','original prompt'],lambda o:c.session_id(o,{agent!r}),{agent!r})\n"
                "sys.exit(__import__('os').waitstatus_to_exitcode(status))\n"
            )
            master, slave = pty.openpty()
            process = subprocess.Popen([sys.executable, str(launcher)], stdin=slave, stdout=slave, stderr=slave)
            os.close(slave)
            output = bytearray()
            deadline = time.monotonic() + 12
            try:
                while time.monotonic() < deadline:
                    if select.select([master], [], [], 0.1)[0]:
                        try:
                            output.extend(os.read(master, 65536))
                        except OSError:
                            break
                    if process.poll() is not None:
                        break
                self.assertEqual(process.wait(timeout=2), 0, output.decode(errors="replace"))
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                os.close(master)
            import json
            launches = [json.loads(line) for line in commands.read_text().splitlines()]
            self.assertEqual(len(launches), 2)
            self.assertEqual(launches[1][-2:], ["resume", session])
            self.assertIn("--yolo", launches[1])
            self.assertNotIn("original prompt", launches[1])
            self.assertIn(b"RESUMED", output)
