import importlib.util
import errno
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


class TitleOptionsTest(unittest.TestCase):
    def test_launch_keeps_platform_title_items_and_agent_identity(self):
        for termux in (False, True):
            module = importlib.util.module_from_spec(SPEC)
            with mock.patch.object(Path, "is_file", return_value=termux):
                SPEC.loader.exec_module(module)
            for agent in ("codex", "traex"):
                with self.subTest(termux=termux, agent=agent), \
                     mock.patch.object(module, "palette_path", return_value=None), \
                     mock.patch.object(module, "theme_signature", return_value=None), \
                     mock.patch.object(module, "spawn_once", return_value=(0, b"", False, None, None)) as spawn:
                    module.run([agent], lambda output: None, agent)
                    launch = spawn.call_args.args[0]
                    settings = launch[launch.index("-c") + 1]
                    self.assertEqual('"activity"' in settings, not termux)
                    self.assertEqual('"thread-title"' in settings, agent == "codex")
                    self.assertEqual('"task-progress"' in settings, agent == "codex")
                    self.assertEqual('"thread-id"' in settings, agent != "codex")


@unittest.skipUnless(sys.platform.startswith("linux"), "Linux inotify")
class ThemeNotificationsTest(unittest.TestCase):
    def test_unavailable_watch_reports_reason_without_reporting_unsupported_hosts(self):
        error = OSError(errno.EMFILE, "inotify_init1")
        report = mock.Mock()
        with mock.patch.dict(os.environ, {"TMUX": "test"}), \
             mock.patch.object(theme, "ThemeNotifications", side_effect=error):
            self.assertIsNone(theme.theme_notifications(None, report))
            report.assert_called_once_with(error)
            report.reset_mock()
            self.assertIsNone(theme.theme_notifications(Path("colors.properties"), report))
            report.assert_not_called()

    def test_atomic_replacement_ignores_same_mode_and_other_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "appearance"
            path.write_text("dark\n")
            watch = theme.ThemeNotifications(path)
            try:
                for mode, expected in (("dark", False), ("light", True), ("light", False), ("dark", True)):
                    temporary = path.with_name("appearance.new")
                    temporary.write_text(mode + "\n")
                    temporary.replace(path)
                    self.assertTrue(select.select([watch.fd], [], [], 1)[0])
                    self.assertEqual(watch.drain(), expected)
                path.with_name("unrelated").write_text("hello")
                self.assertFalse(watch.drain())
            finally:
                watch.close()

    def test_missing_state_keeps_polling_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.dict(os.environ, {"TMUX": "test", "XDG_STATE_HOME": directory}):
                self.assertIsNone(theme.theme_notifications(None))
                Path(directory, "appearance").write_text("dark")
                watch = theme.theme_notifications(None)
                self.assertIsNotNone(watch)
                watch.close()
                self.assertIsNone(theme.theme_notifications(Path(directory, "colors.properties")))

    def test_removed_watch_directory_requests_polling_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory) / "state"
            parent.mkdir()
            path = parent / "appearance"
            path.write_text("dark")
            watch = theme.ThemeNotifications(path)
            try:
                path.unlink()
                parent.rmdir()
                self.assertTrue(select.select([watch.fd], [], [], 1)[0])
                with self.assertRaises(OSError):
                    watch.drain()
            finally:
                watch.close()


class ColorRepliesTest(unittest.TestCase):
    def test_consumes_own_replies_with_every_possible_read_split(self):
        replies = b"\x1b]10;rgb:aaaa/b2b2/bfbf\x07\x1b]11;rgb:2828/2c2c/3434\x1b\\"
        for split in range(len(replies) + 1):
            with self.subTest(split=split):
                parser = theme.ColorReplies()
                parser.queried()
                forwarded = parser.forward(b"\x04" + replies[:split])
                forwarded += parser.forward(replies[split:] + b"next command\r")
                self.assertEqual(forwarded, b"\x04next command\r")
                self.assertFalse(parser.pending)

    def test_real_pty_does_not_echo_monitor_replies_during_exit(self):
        master, slave = pty.openpty()
        command = [sys.executable, "-B", "-c",
                   "import sys,time; print('EXITING',flush=True); time.sleep(0.3)"]
        runner = (
            "import sys; sys.path.insert(0,sys.argv[1]); "
            "import agent_theme_restart as t; "
            "t.spawn_once(sys.argv[2:],None,None)"
        )
        process = subprocess.Popen(
            [sys.executable, "-B", "-c", runner, str(ROOT / "config/zsh"), *command],
            stdin=slave, stdout=slave, stderr=slave,
        )
        os.close(slave)
        output = bytearray()
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        break
                    output.extend(chunk)
                    if b"\x1b]11;?\x07" in output:
                        os.write(master, b"\x1b]10;rgb:aaaa/b2b2/bfbf\x07\x1b]11;rgb:2828/2c2c/3434\x07")
                        # Respond only once, even if subsequent output arrives.
                        output[:] = output.replace(b"\x1b]11;?\x07", b"QUERY")
                if process.poll() is not None:
                    break
            self.assertEqual(process.wait(timeout=2), 0)
            self.assertIn(b"EXITING", output)
            self.assertIn(b"QUERY", output)
            self.assertNotIn(b"rgb:", output)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

    def test_preserves_child_replies_and_keyboard_sequences(self):
        parser = theme.ColorReplies()
        reply = b"\x1b]10;rgb:aa/bb/cc\x07"
        self.assertEqual(parser.forward(reply), reply)
        parser.queried()
        keys = b"draft\x1b[A\x1bx\r"
        self.assertEqual(parser.forward(keys), keys)
        self.assertEqual(parser.forward(reply + reply), reply)


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

    def test_readable_thread_title_with_progress_authorizes_only_that_named_thread(self):
        gate = theme.RestartGate(0)
        gate.seen_work = True
        gate.output("\x1b]2;Codex | Ready | 修复公式布局 | 2/5\x07".encode(), 1)
        self.assertTrue(gate.can_quit(3))
        self.assertEqual(gate.thread_prefix, "name:修复公式布局")
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {"CODEX_HOME": directory}):
            Path(directory, 'session_index.jsonl').write_text(
                '{"id":"correct","thread_name":"修复公式布局"}\n'
                '{"id":"other","thread_name":"其他任务"}\n', encoding='utf-8')
            self.assertTrue(theme.exit_matches_thread('correct', gate.thread_prefix))
            self.assertFalse(theme.exit_matches_thread('other', gate.thread_prefix))
            self.assertFalse(theme.exit_matches_thread('missing', gate.thread_prefix))
        gate.output(b"\x1b]2;Codex | Ready | 2/5\x07", 4)
        self.assertFalse(gate.can_quit(100))

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

    def test_pane_focus_foreground_changes_do_not_refresh(self):
        gate = theme.RestartGate(0)
        gate.input(b"\x1b]10;rgb:aa/b2/bf\x07\x1b]11;rgb:28/2c/34\x07", 0)
        for foreground in (b"5c/63/70", b"aa/b2/bf", b"5c/63/70"):
            gate.input(b"\x1b]10;rgb:" + foreground + b"\x07", 5)
            self.assertIsNone(gate.refresh_signature(None, None))
        self.assertFalse(gate.dirty)

    def test_pane_focus_does_not_reset_background_change_debounce(self):
        gate = theme.RestartGate(0)
        gate.input(b"\x1b]10;rgb:aa/b2/bf\x07\x1b]11;rgb:28/2c/34\x07", 0)
        gate.input(b"\x1b]10;rgb:38/3a/42\x07\x1b]11;rgb:fa/fa/fa\x07", 5)
        refresh = gate.refresh_signature(None, None)
        self.assertIsNotNone(refresh)
        gate.input(b"\x1b]10;rgb:a0/a1/a7\x07", 6)
        self.assertEqual(gate.refresh_signature(None, None), refresh)

    def test_palette_file_foreground_change_still_waits_for_delivery(self):
        baseline = b"foreground=#aab2bf\nbackground=#282c34\n"
        current = b"foreground=#cdd6f4\nbackground=#282c34\n"
        gate = theme.RestartGate(0)
        gate.input(b"\x1b]10;rgb:aa/b2/bf\x07\x1b]11;rgb:28/2c/34\x07", 0)
        self.assertIsNone(gate.refresh_signature(current, baseline))
        gate.input(b"\x1b]10;rgb:cd/d6/f4\x07", 5)
        self.assertIsNotNone(gate.refresh_signature(current, baseline))

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
            with mock.patch.dict(theme.os.environ, {"CODEX_THEME_RESTART": "1"}):
                self.assertTrue(theme.enabled(["codex"], "codex"))
                with mock.patch.dict(theme.os.environ, {"AGENT_THEME_RESTART": "0"}):
                    self.assertFalse(theme.enabled(["codex"], "codex"))

    def test_tmux_focus_foreground_changes_do_not_authorize_restart(self):
        gate = theme.RestartGate(0)
        gate.input(b"\x1b]10;rgb:aaaa/b2b2/bfbf\x07\x1b]11;rgb:2828/2c2c/3434\x07", 0)
        gate.output(title("Working"), 0)
        gate.output(title("Ready"), 1)
        for foreground in (b"5c5c/6363/7070", b"aaaa/b2b2/bfbf"):
            gate.input(b"\x1b]10;rgb:" + foreground + b"\x07", 5)
            self.assertTrue(gate.can_quit(10))
            self.assertIsNone(gate.refresh_signature(None, None))
        # A real dark/light background transition must still refresh.
        gate.input(b"\x1b]11;rgb:efef/f1f1/f5f5\x07", 15)
        self.assertIsNotNone(gate.refresh_signature(None, None))

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

    def test_relaunch_retains_scene_and_temporary_adjustment(self):
        self.assertEqual(theme.resume_options([
            "codex-team", "--scene", "hard", "--adjust", "quick", "resume", "thread-id"
        ]), ["--scene", "hard", "--adjust", "quick"])

    def test_relaunch_retains_settings_without_replaying_prompt(self):
        self.assertEqual(theme.resume_options([
            "codex", "--yolo", "-p", "expert", "-C", "/repo with spaces",
            "--add-dir=/other", "resume", "--last", "initial prompt",
        ]), ["--yolo", "-p", "expert", "-C", "/repo with spaces", "--add-dir=/other"])
        for option in ("--no-daemon", "--worktree", "-i", "--unknown", "fork"):
            self.assertIsNone(theme.resume_options(["codex", option]))


@unittest.skipUnless(hasattr(os, "fork"), "PTY supervisor requires POSIX")
class SupervisorTest(unittest.TestCase):
    def test_pane_focus_foreground_change_never_quits_or_resumes(self):
        session = "01a12a2b-3287-7bf2-8fc1-661e52ea78b1"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "appearance").write_text("dark")
            child = root / "codex"
            child.write_text(
                f"#!{sys.executable}\n"
                "import os,select,sys,time,tty\n"
                "tty.setraw(0)\n"
                "if 'resume' in sys.argv: print('UNEXPECTED_RESUME',flush=True);sys.exit(93)\n"
                "os.write(1,b'\\x1b]0;codex | Working\\x07')\n"
                f"os.write(1,b'\\x1b]0;codex | Ready | {session}\\x07')\n"
                "start=time.monotonic();queried=False\n"
                "while time.monotonic()-start<3.5:\n"
                " if not queried and time.monotonic()-start>=0.5:\n"
                "  os.write(1,b'INACTIVE\\x1b]10;?\\x07\\x1b]11;?\\x07');queried=True\n"
                " if select.select([0],[],[],0.05)[0] and b'\\x04' in os.read(0,4096):\n"
                f"  os.write(1,b'\\r\\nSession ID: {session}\\r\\n');sys.exit(0)\n"
                "print('NO_RESTART',flush=True)\n"
            )
            child.chmod(0o755)
            master, slave = pty.openpty()
            env = dict(os.environ, TMUX="test", XDG_STATE_HOME=str(root))
            env.pop("AGENT_THEME_RESTART", None)
            env.pop("CODEX_THEME_RESTART", None)
            process = subprocess.Popen(
                [sys.executable, "-B", str(ROOT / "config/zsh/agent-capture-session.py"),
                 str(root / "session"), str(child)],
                stdin=slave, stdout=slave, stderr=slave, env=env,
            )
            os.close(slave)
            output = bytearray()
            pending = bytearray()
            deadline = time.monotonic() + 8
            try:
                while time.monotonic() < deadline:
                    if select.select([master], [], [], 0.1)[0]:
                        try:
                            chunk = os.read(master, 65536)
                        except OSError:
                            break
                        output.extend(chunk)
                        pending.extend(chunk)
                        for code in (10, 11):
                            query = f"\x1b]{code};?\x07".encode()
                            while query in pending:
                                start = pending.index(query)
                                del pending[start:start + len(query)]
                                foreground = "5c/63/70" if b"INACTIVE" in output else "aa/b2/bf"
                                color = foreground if code == 10 else "28/2c/34"
                                os.write(master, f"\x1b]{code};rgb:{color}\x07".encode())
                        del pending[:-4096]
                    if process.poll() is not None:
                        break
                self.assertEqual(process.wait(timeout=2), 0, output.decode(errors="replace"))
                self.assertIn(b"INACTIVE", output)
                self.assertIn(b"NO_RESTART", output)
                self.assertNotIn(b"UNEXPECTED_RESUME", output)
                self.assertNotIn(b"refreshing terminal theme", output)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                os.close(master)

    def test_real_pty_waits_for_completion_and_resumes_exact_id(self):
        self.check_pty_agent("codex")

    def test_slow_shutdown_still_resumes_exact_id(self):
        self.check_pty_agent("codex", shutdown_delay=4)

    def test_traex_pty_waits_for_completion_and_resumes_exact_id(self):
        self.check_pty_agent("traex")

    def test_terminal_only_pty_refresh_without_a_palette_file(self):
        self.check_terminal_only_refresh(False)

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux inotify")
    def test_tmux_idle_stops_queries_and_state_event_resumes_exact_thread(self):
        self.check_terminal_only_refresh(True)

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux inotify")
    def test_tmux_watch_recovers_after_initial_quota_failures(self):
        self.check_terminal_only_refresh(True, "startup")

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux inotify")
    def test_tmux_lost_watch_is_closed_and_recovers(self):
        self.check_terminal_only_refresh(True, "lost")

    def check_terminal_only_refresh(self, watched, watch_failure=None):
        session = "01a12a2b-3287-7bf2-8fc1-661e52ea78b1"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "appearance"
            state.write_text("dark")
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
                "deadline=time.monotonic()+18\n"
                "while time.monotonic()<deadline:\n"
                " if select.select([0],[],[],0.1)[0] and b'\\x04' in os.read(0,4096):\n"
                f"  os.write(1,b'\\r\\ntraecli resume {session}\\r\\n');sys.exit(0)\n"
                "sys.exit(92)\n"
            )
            child.chmod(0o755)
            launcher = root / "launcher.py"
            recovery_setup = ""
            if watch_failure is not None:
                recovery_setup = (
                    "import errno,time\nfrom pathlib import Path\n"
                    "t.THEME_WATCH_RETRY_SECONDS=0.3\n"
                    "original=t.ThemeNotifications;attempts=0\n"
                    "class FaultyNotifications(original):\n"
                    " def __init__(self,path):\n"
                    "  global attempts\n"
                    "  attempts+=1;self.first=attempts==1\n"
                    f"  with Path({str(root / 'watch-attempts')!r}).open('a') as f:f.write(str(time.monotonic())+'\\n')\n"
                    + ("  if attempts<=3:raise OSError(errno.EMFILE,'inotify_init1')\n"
                       if watch_failure == "startup" else "") +
                    "  super().__init__(path)\n"
                    " def drain(self):\n"
                    + ("  if self.first:raise OSError('Appearance watch lost')\n"
                       if watch_failure == "lost" else "") +
                    "  changed=super().drain()\n"
                    "  if changed:os.write(2,b'RECOVERED_WATCH_EVENT\\r\\n')\n"
                    "  return changed\n"
                    "t.ThemeNotifications=FaultyNotifications\n"
                )
            launcher.write_text(
                "import sys,os,importlib.util\n"
                f"sys.path.insert(0,{str(ROOT / 'config/zsh')!r})\n"
                "import agent_theme_restart as t\n"
                f"s=importlib.util.spec_from_file_location('capture',{str(ROOT / 'config/zsh/agent-capture-session.py')!r})\n"
                "c=importlib.util.module_from_spec(s);s.loader.exec_module(c)\n"
                "t.palette_path=lambda:None\n"
                + recovery_setup +
                f"status,_=t.run([{str(child)!r}],lambda o:c.session_id(o,'traex'),'traex')\n"
                "sys.exit(os.waitstatus_to_exitcode(status))\n"
            )
            master, slave = pty.openpty()
            env = dict(os.environ)
            env.pop("TMUX", None)
            if watched:
                env.update(TMUX="test", XDG_STATE_HOME=str(root))
            process = subprocess.Popen([sys.executable, str(launcher)], stdin=slave, stdout=slave, stderr=slave, env=env)
            os.close(slave)
            output = bytearray()
            pending = bytearray()
            light = False
            started = time.monotonic()
            deadline = started + 24
            initial_queries = 0
            lost_event_sent = False
            try:
                while time.monotonic() < deadline:
                    if watch_failure == "lost" and not lost_event_sent and time.monotonic() - started >= 1:
                        temporary = root / "appearance.new"
                        temporary.write_text("dark")
                        temporary.replace(state)
                        lost_event_sent = True
                    if watched and not light and time.monotonic() - started >= 6:
                        if watch_failure is None:
                            self.assertEqual(initial_queries, 2, "Idle tmux wrapper must query only at startup")
                        temporary = root / "appearance.new"
                        temporary.write_text("light")
                        temporary.replace(state)
                        light = True
                    if select.select([master], [], [], 0.1)[0]:
                        try:
                            chunk = os.read(master, 65536)
                        except OSError:
                            break
                        output.extend(chunk)
                        pending.extend(chunk)
                        if not watched and b"DISPLAY_LIGHT" in output:
                            light = True
                        for code in (10, 11):
                            query = f"\x1b]{code};?\x07".encode()
                            while query in pending:
                                if not light:
                                    initial_queries += 1
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
                if watch_failure is not None:
                    self.assertEqual(output.count(b"theme watch unavailable"), 1)
                    self.assertEqual(output.count(b"theme watch restored"), 1)
                    self.assertIn(b"RECOVERED_WATCH_EVENT", output)
                    attempts = [float(value) for value in (root / "watch-attempts").read_text().splitlines()]
                    if watch_failure == "startup":
                        self.assertGreaterEqual(len(attempts), 4)
                        self.assertTrue(all(b - a >= 0.2 for a, b in zip(attempts[:3], attempts[1:4])))
                        self.assertIn(b"inotify_init1", output)
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

    def check_pty_agent(self, agent, shutdown_delay=0):
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
                f"time.sleep({shutdown_delay!r})\n"
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
