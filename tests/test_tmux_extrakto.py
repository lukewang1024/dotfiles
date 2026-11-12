"""Regression cases for text rendered in narrow terminal panes."""

import importlib.machinery
import importlib.util
import base64
import json
import os
from pathlib import Path
import select
import shlex
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "util/shell/tmux-extrakto"
loader = importlib.machinery.SourceFileLoader("tmux_extrakto", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class UrlExtractionTests(unittest.TestCase):
    def test_indented_continuation_and_query(self):
        text = "  https://example.com/very/\n    long/path?key=value&\n    page=2"
        self.assertEqual(module.extract_urls(text), [
            "https://example.com/very/long/path?key=value&page=2"
        ])

    def test_padding_inside_wrapped_url(self):
        text = "https://example.com/very/    long/path?key=value"
        self.assertEqual(module.extract_urls(text), ["https://example.com/very/long/path?key=value"])

    def test_opaque_id_at_pane_edge(self):
        text = "  https://example.com/path/abcdefghijklm\n  nopqrstuvwxyz0123456789"
        self.assertEqual(module.extract_urls(text, 40), [
            "https://example.com/path/abcdefghijklmnopqrstuvwxyz0123456789"
        ])

    def test_normal_prose_and_other_urls_stay_separate(self):
        text = "https://example.com/path next steps\n  More information\nhttps://other.example/path"
        self.assertEqual(module.extract_urls(text), [
            "https://example.com/path", "https://other.example/path"
        ])

    def test_blank_line_is_a_boundary(self):
        self.assertEqual(module.extract_urls("https://example.com/\n\n  another/path"), [
            "https://example.com/"
        ])

    def test_joined_soft_wrap_does_not_absorb_the_next_heading(self):
        url = "https://example.com/" + "segment/" * 7 + "end?x=1&y=2"
        self.assertEqual(module.extract_urls(url + "\nHARD", 48), [url])
        url = "https://example.com/padded/    long/path?x=1&y=2"
        self.assertEqual(module.extract_urls(url + "\nHIDDEN", 48), [
            "https://example.com/padded/long/path?x=1&y=2"
        ])

    def test_markdown_and_balanced_parentheses(self):
        text = "[link](https://example.com/a_(b)?x=1&y=2)."
        self.assertEqual(module.extract_urls(text), ["https://example.com/a_(b)?x=1&y=2"])

    def test_ipv6_and_encoded_space_are_preserved(self):
        text = "https://[::1]:8080/a%20b?x=1&y=2#fragment"
        self.assertEqual(module.extract_urls(text), [text])

    def test_ellipsis_is_not_offered_as_a_complete_url(self):
        for text in ("https://example.com/very/…", "https://example.com/very/.../path"):
            with self.subTest(text=text):
                self.assertEqual(module.extract_urls(text), [])

    def test_osc8_with_both_terminators(self):
        target = "https://example.com/full/target?x=1&y=2"
        for end in ("\x07", "\x1b\\"):
            with self.subTest(end=end):
                raw = f"\x1b[32m\x1b]8;id=one;{target}{end}short…\x1b]8;;{end}\x1b[0m"
                self.assertEqual(module.decode_capture(raw), ("short…", [target]))

    def test_panes_are_not_joined_and_canonical_target_is_kept(self):
        target = "https://example.com/full/target?x=1&y=2"
        captures = {"panes": [("https://example.com/", 40), ("  other/path", 40)],
                    "targets": [target]}
        original = SimpleNamespace(
            min_length=5, extrakto=SimpleNamespace(alt=False, prefix_name=True)
        )
        self.assertEqual(module.UrlFilter(original, captures).filter(""), [
            "url: https://example.com/", "url: " + target
        ])


class ParagraphExtractionTests(unittest.TestCase):
    def test_codex_chinese_wrap_and_right_padding(self):
        text = "• 这是一个很长的段      \n  落，用来验证 Codex 的换    \n  行处理。        \n\n  这是第二段。"
        self.assertEqual(module.extract_paragraphs(text), [
            "这是一个很长的段落，用来验证 Codex 的换行处理。", "这是第二段。"
        ])

    def test_english_wrap_keeps_word_spaces(self):
        text = "• This paragraph wraps across\n  several terminal rows.\n\n  Another paragraph follows."
        self.assertEqual(module.extract_paragraphs(text), [
            "This paragraph wraps across several terminal rows.", "Another paragraph follows."
        ])

    def test_list_items_and_messages_are_separate(self):
        text = "• - 第一项还很\n    长。\n  - 第二项内容。\n› 用户的新消息。\n• 助手的新回复。"
        self.assertEqual(module.extract_paragraphs(text), [
            "- 第一项还很长。", "- 第二项内容。", "用户的新消息。", "助手的新回复。"
        ])

    def test_fenced_code_and_tables_are_not_flattened_into_prose(self):
        text = "前面的一段话。\n```python\nx = 1\ny = 2\n```\n| field | value |\n后面的一段话。"
        self.assertEqual(module.extract_paragraphs(text), ["前面的一段话。", "后面的一段话。"])

    def test_codex_chrome_is_excluded(self):
        text = ("• 一段有效正文。\n\n• Working (1m 53s • esc to interrupt)\n"
                "  └ Tip: Press f3 to search this conversation.\n› Ask Codex to do anything\n"
                "  GPT-6.1 max fast · /tmp\n  ? for shortcuts")
        self.assertEqual(module.extract_paragraphs(text), ["一段有效正文。"])

    def test_filter_keeps_panes_separate_and_marks_all_mode_entries(self):
        engine = SimpleNamespace(min_length=None, prefix_name=True)
        captures = {"panes": [("这是第一个窗格。", 48), ("这是第二个窗格。", 48)]}
        self.assertEqual(module.ParagraphFilter(engine, captures).filter(""), [
            "paragraph: 这是第一个窗格。", "paragraph: 这是第二个窗格。"
        ])


class ParagraphMultiSelectionTests(unittest.TestCase):
    def test_paragraphs_are_sorted_by_candidate_order_and_mixed_rows_are_unchanged(self):
        candidates = ["paragraph: newest", "paragraph: middle", "paragraph: oldest"]
        self.assertEqual(
            module.paragraph_selections(
                ["paragraph: oldest", "paragraph: newest"], "all", "all", candidates,
            ),
            ["newest", "oldest"],
        )
        self.assertIsNone(module.paragraph_selections(
            ["paragraph: newest", "path: /tmp/file"], "all", "all", candidates,
        ))

    def test_space_toggle_preserves_search_space_with_alt_space(self):
        picker, observed = self.make_picker(
            "all", "enter", ["paragraph: older", "paragraph: newer"],
            ["paragraph: newer", "paragraph: older"],
        )
        picker.capture()
        command = observed["command"]
        self.assertIn("--marker=✓", command)
        binding = next(arg for arg in command if arg.startswith("--bind="))
        self.assertIn("space:toggle+up,", binding)
        self.assertIn(
            "alt-space:transform(printf 'change-query(%s )' \"$FZF_QUERY\")",
            binding,
        )
        header = next(arg for arg in command if arg.startswith("--header="))
        self.assertIn("Space=toggle, Alt-Space=query space", header)
        self.assertEqual(observed["copied"], "newer\n\nolder")

    def test_reverse_layout_advances_down_into_the_list(self):
        picker, observed = self.make_picker(
            "paragraph", "enter", ["one paragraph"], ["one paragraph"],
        )
        picker.fzf_layout = "reverse"
        picker.capture()
        binding = next(arg for arg in observed["command"] if arg.startswith("--bind="))
        self.assertIn("space:toggle+down,", binding)

    def test_insert_uses_the_same_order_and_blank_line_separator(self):
        picker, observed = self.make_picker(
            "paragraph", "alt-enter", ["oldest", "newest"],
            ["newest", "middle", "oldest"],
        )
        with patch.object(module.subprocess, "run") as run:
            picker.capture()
        self.assertEqual(run.call_args_list[0].args[0], [
            "tmux", "set-buffer", "--", "newest\n\noldest",
        ])
        self.assertEqual(run.call_args_list[1].args[0], [
            "tmux", "paste-buffer", "-p", "-t", "%7",
        ])
        self.assertNotIn("copied", observed)

    def test_single_paragraph_copy_keeps_the_existing_text(self):
        picker, observed = self.make_picker(
            "paragraph", "enter", ["one paragraph"], ["one paragraph"],
        )
        picker.capture()
        self.assertEqual(observed["copied"], "one paragraph")

    @staticmethod
    def make_picker(filter_key, key, selection, candidates):
        observed = {}

        class Engine:
            def __init__(self, **kwargs):
                self.prefix_name = kwargs.get("prefix_name", False)

            def __getitem__(self, name):
                raise KeyError(name)

            def all(self):
                return []

        class Plugin:
            def __init__(self, pane, mode):
                self.trigger_pane = pane
                self.copy_key = "enter"
                self.insert_key = "alt-enter"
                self.edit_key = "ctrl-e"
                self.prefix_name = "all"
                self.clip_mode = "buffer"
                self.fzf_header = "enter=copy, alt-enter=insert"
                self.fzf_layout = "default"

            def capture(self):
                data = upstream.get_cap(filter_key, "captured pane")
                query, selected_key, *items = upstream.fzf_sel(
                    ["fzf", "--multi", "--header=enter=copy"], data,
                )
                if (self.prefix_name == "all" and filter_key == "all") or self.prefix_name == "any":
                    items = [next(iter(item.split(": ", 1)[1:2]), item) for item in items]
                text = "\n".join(items) if filter_key in ("all", "line") else " ".join(items)
                if selected_key == self.copy_key:
                    self.copy(text)
                elif selected_key == self.insert_key:
                    module.subprocess.run(["tmux", "set-buffer", "--", text], check=True)
                    module.subprocess.run(
                        ["tmux", "paste-buffer", "-p", "-t", self.trigger_pane], check=True,
                    )
                return 0

            def copy(self, text):
                observed["copied"] = text

        def get_cap(mode, data):
            return "\n".join(candidates)

        def fzf_sel(command, data):
            observed["command"] = command
            observed["data"] = data
            return ["", key, *selection]

        upstream = SimpleNamespace(
            Extrakto=Engine,
            ExtraktoPlugin=Plugin,
            get_cap=get_cap,
            fzf_sel=fzf_sel,
            get_option=lambda name: "",
            get_option_only=lambda name: "",
        )
        enhanced = module.enhance(upstream)
        return enhanced("%7", "popup"), observed


class TerminalTransportTests(unittest.TestCase):
    def test_osc52_preserves_unicode_and_newlines(self):
        text = "完整段落。\nhttps://example.com/a?x=1&y=2#part"
        frame = module.clipboard_sequence(text)
        self.assertTrue(frame.startswith(b"\x1b]52;c;"))
        self.assertTrue(frame.endswith(b"\x07"))
        self.assertEqual(base64.b64decode(frame[7:-1]).decode("utf-8"), text)

    def test_iterm_open_url_uses_base64_without_shell_interpretation(self):
        url = "https://example.com/a?x=1&y=2#part"
        frame = module.open_url_sequence(url)
        prefix = b"\x1b]1337;OpenURL=:"
        self.assertTrue(frame.startswith(prefix))
        self.assertTrue(frame.endswith(b"\x07"))
        self.assertEqual(base64.b64decode(frame[len(prefix):-1]).decode("utf-8"), url)

    @unittest.skipUnless(os.name == "posix", "PTY transport")
    def test_only_the_invoking_clients_outer_pty_receives_the_sequence(self):
        import pty

        master_a, slave_a = pty.openpty()
        master_b, slave_b = pty.openpty()
        for fd in (master_a, slave_a, master_b, slave_b):
            self.addCleanup(os.close, fd)
        ttys = {"client-a": os.ttyname(slave_a), "client-b": os.ttyname(slave_b)}

        def info(command, **kwargs):
            client = command[command.index("-c") + 1]
            return f"{client}\t{ttys[client]}\tiTerm2 3.7.6\n"

        frame = module.clipboard_sequence("宿主机剪贴板")
        with patch.object(module.subprocess, "check_output", side_effect=info):
            module.write_terminal("client-a", frame)
        self.assertEqual(os.read(master_a, len(frame)), frame)
        self.assertEqual(select.select([master_b], [], [], 0)[0], [])

    def test_detached_client_is_not_replaced_with_another_client(self):
        with patch.object(module.subprocess, "check_output", return_value="\t\t\n"):
            with self.assertRaisesRegex(RuntimeError, "no longer attached"):
                module.terminal_info("disconnected-client")

    @unittest.skipUnless(os.name == "posix", "TTY validation")
    def test_non_terminal_destination_is_rejected_before_writing(self):
        with tempfile.NamedTemporaryFile() as target:
            with patch.object(module, "terminal_info", return_value={"tty": target.name}):
                with self.assertRaisesRegex(RuntimeError, "no interactive terminal"):
                    module.write_terminal("client-a", b"do not write this")
            self.assertEqual(Path(target.name).read_bytes(), b"")


class PickerLaunchTests(unittest.TestCase):
    def test_explicit_type_reaches_capture_and_can_cycle_to_general_text(self):
        selected = []

        class Picker:
            fzf_tool = "fzf"

            def __init__(self, pane, mode):
                self.next_filter = {"all": "word", "word": "all", "initial": "all"}

            def prep_cycle(self, keys):
                # Upstream supplies only the cycle, without an initial entry.
                return dict(zip(keys, keys[1:] + keys[:1]))

            def capture(self):
                current = self.next_filter["initial"]
                selected.extend([current, self.next_filter[current]])
                return 0

        upstream = SimpleNamespace(Extrakto=lambda: SimpleNamespace(keys=lambda: ["path", "word"]))
        argv = ["tmux-extrakto", "--client", "client-a", "--filter", "path", "%42", "popup"]
        with patch.object(module.sys, "argv", argv), \
             patch.object(module, "load_upstream", return_value=upstream), \
             patch.object(module, "enhance", return_value=Picker), \
             patch.object(module.subprocess, "run", return_value=SimpleNamespace(stdout="")):
            self.assertEqual(module.main(), 0)
        self.assertEqual(selected, ["path", "all"])

    def test_menu_filter_and_invoking_client_survive_the_popup_launch(self):
        upstream = SimpleNamespace(get_option_only=lambda name: None)
        with patch.object(module.subprocess, "check_output", return_value="/tmp/source directory\n"), \
             patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0)) as run:
            self.assertEqual(module.launch(upstream, "%42", client="/dev/pts/7", filter_key="path"), 0)
        command = run.call_args.args[0]
        child = shlex.split(command[-1])
        self.assertEqual(command[command.index("-t") + 1], "/dev/pts/7")
        self.assertEqual(command[command.index("-d") + 1], "/tmp/source directory")
        self.assertEqual(child[child.index("--client") + 1], "/dev/pts/7")
        self.assertEqual(child[child.index("--filter") + 1], "path")
        self.assertEqual(child[-2:], ["%42", "popup"])


class HostOpenTests(unittest.TestCase):
    def test_remote_iterm_without_a_bridge_explains_the_permission_prompt(self):
        with patch.object(module, "terminal_info", return_value={"tty": "mac-tty", "type": "iTerm2 3.7.6"}), \
             patch.object(module.shutil, "which", return_value="/bin/workbench"), \
             patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout='{"clients": []}')) as run, \
             patch.dict(module.os.environ, {"SSH_CONNECTION": "fixture"}), \
             patch.object(module, "write_terminal") as write:
            self.assertTrue(module.open_host_urls("mac-client", ["https://example.com/"]))
            write.assert_called_once_with("mac-client", module.open_url_sequence("https://example.com/"))
            command = run.call_args.args[0]
            self.assertEqual(command[:5], ["tmux", "display-message", "-c", "mac-client", "-d"])
            self.assertIn('click Allow', command[-1])
            self.assertNotIn('opened', command[-1])

    def test_old_iterm_client_can_still_request_opening_through_osc(self):
        endpoints = [{"attachment": "mac-tty", "capabilities": ["clipboard"]}]
        with patch.object(module, "terminal_info", return_value={"tty": "mac-tty", "type": "iTerm2 3.7.6"}), \
             patch.object(module.shutil, "which", return_value="/bin/workbench"), \
             patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=json.dumps({"clients": endpoints}))), \
             patch.object(module, "write_terminal") as write:
            self.assertTrue(module.open_host_urls("mac-client", ["https://example.com/"]))
            write.assert_called_once_with("mac-client", module.open_url_sequence("https://example.com/"))

    def test_iterm_prefers_the_native_bridge_without_sending_osc(self):
        endpoints = [{"attachment": "mac-tty", "capabilities": ["open-url"]}]
        commands = []
        def run(command, **kwargs):
            commands.append(command)
            return SimpleNamespace(returncode=0, stdout=json.dumps({"clients": endpoints}), stderr="")
        with patch.object(module, "terminal_info", return_value={"tty": "mac-tty", "type": "iTerm2 3.7.6"}), \
             patch.object(module.shutil, "which", return_value="/bin/workbench"), \
             patch.object(module.subprocess, "run", side_effect=run), \
             patch.object(module, "write_terminal") as write:
            self.assertTrue(module.open_host_urls("mac-client", ["https://example.com/"]))
            write.assert_not_called()
        self.assertEqual(commands[-1], ["/bin/workbench", "client", "open-url", "--client", "mac-client", "--", "https://example.com/"])

    def test_termux_bridge_is_selected_by_exact_attachment(self):
        endpoints = [{"attachment": "mac-tty", "capabilities": ["open-url"]},
                     {"attachment": "phone-tty", "capabilities": ["open-url"]}]
        commands = []
        def run(command, **kwargs):
            commands.append(command)
            return SimpleNamespace(returncode=0, stdout=json.dumps({"clients": endpoints}), stderr="")
        with patch.object(module, "terminal_info", return_value={"tty": "phone-tty", "type": ""}), \
             patch.object(module.shutil, "which", return_value="/bin/workbench"), \
             patch.object(module.subprocess, "run", side_effect=run):
            self.assertTrue(module.open_host_urls("phone-client", ["https://example.com/?x=1&y=2"]))
        self.assertEqual(commands[-1], ["/bin/workbench", "client", "open-url", "--client", "phone-client", "--", "https://example.com/?x=1&y=2"])

    def test_old_phone_client_never_opens_on_the_other_attached_mac(self):
        endpoints = [{"attachment": "mac-tty", "capabilities": ["open-url"]},
                     {"attachment": "phone-tty", "capabilities": []}]
        with patch.object(module, "terminal_info", return_value={"tty": "phone-tty", "type": ""}), \
             patch.object(module.shutil, "which", return_value="/bin/workbench"), \
             patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=json.dumps({"clients": endpoints}))), \
             patch.object(module, "write_terminal") as write:
            with self.assertRaisesRegex(RuntimeError, "Update Workbench"):
                module.open_host_urls("phone-client", ["https://example.com/"])
            write.assert_not_called()


if __name__ == "__main__":
    unittest.main()
