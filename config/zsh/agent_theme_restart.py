"""Refresh supported agent TUIs after a terminal palette change on POSIX."""

import errno
import os
from pathlib import Path
import pty
import re
import select
import signal
import termios
import time
import tty


# These are frontend-only overrides. Ctrl+D remains the normal empty-composer
# quit shortcut, but cannot delete draft text when the composer refuses to quit.
UI_OPTIONS = [
    "-c", 'tui.terminal_title=["app-name","run-state","activity","thread-id"]',
    "-c", 'tui.keymap.editor.delete_forward=["delete","shift-delete"]',
]
RECONNECT_OPTIONS = [
    "-c", "check_for_update_on_startup=false",
    "-c", 'tui.resume_cwd="session"',
]

VALUE_OPTIONS = {
    "-c", "--config", "--enable", "--disable", "-m", "--model",
    "-p", "--profile", "-s", "--sandbox", "-a", "--ask-for-approval",
    "-C", "--cd", "--add-dir", "--remote", "--remote-auth-token-env",
}
FLAG_OPTIONS = {
    "--yolo", "--dangerously-bypass-approvals-and-sandbox", "--approve-for-me",
    "--dangerously-bypass-hook-trust", "--no-alt-screen", "--search",
    "--strict-config", "--oss",
}
RESUME_FLAGS = {"--last", "--all", "--include-non-interactive"}
NON_INTERACTIVE_COMMANDS = {
    "fork", "exec", "e", "review", "app-server", "agents", "queue",
    "archive", "delete", "migrate-rollouts", "unarchive", "cloud", "mcp",
    "plugin", "remote-control", "completion", "doctor", "sandbox", "debug",
    "apply", "a", "features", "help", "login", "logout", "update",
    "acp", "mcp-server",
}


def resume_options(command, agent="codex"):
    """Keep launch settings, dropping the initial prompt/resume target.

    Unknown options, image inputs, worktrees, forks and embedded servers fail
    closed: their startup side effects cannot safely be replayed.
    """
    value_options = set(VALUE_OPTIONS)
    flag_options = set(FLAG_OPTIONS)
    if agent == "traex":
        value_options.update({"--permission-mode", "--allowed-tool", "--disallowed-tool"})
        flag_options.add("-y")
    options = []
    args = iter(command[1:])
    for arg in args:
        if arg in value_options:
            value = next(args, None)
            if value is None:
                return None
            options.extend([arg, value])
        elif arg in flag_options:
            options.append(arg)
        elif arg in RESUME_FLAGS:
            continue
        elif arg.startswith("--") and arg.split("=", 1)[0] in value_options:
            options.append(arg)
        elif arg.startswith("-") or arg in NON_INTERACTIVE_COMMANDS:
            return None
        # Remaining positional arguments are the prompt, resume verb or ID.
    return options


def enabled(command, agent="codex"):
    return (
        agent in {"codex", "traex"}
        and os.environ.get("AGENT_THEME_RESTART", "1") != "0"
        and os.environ.get(f"{agent.upper()}_THEME_RESTART", "1") != "0"
        and os.name == "posix"
        and os.isatty(0)
        and os.isatty(1)
        and resume_options(command, agent) is not None
    )


def theme_signature(path):
    if path is None:
        return None
    try:
        # Read effective colors: a symlink replacement or an in-place edit both
        # count, while replacing a link with identical colors does not.
        return path.read_bytes()
    except OSError:
        return None


class RestartGate:
    """Consume the agent's own OSC title states, never infer idle from silence."""

    def __init__(self, now, agent="codex"):
        self.agent = agent
        self.title_bytes = bytearray()
        self.ready_since = None
        self.last_input = now
        self.dirty = False
        self.submitted = False
        self.input_sequence = bytearray()
        self.pasting = False
        self.seen_work = False
        self.thread_prefix = None
        self.terminal_colors = {}
        self.initial_terminal_colors = None

    def input(self, data, now):
        # Conservatively keep drafts protected. A plain Enter is not proof of
        # submission (it can insert a newline); only the following Working or
        # Thinking title confirms it. Terminal replies are not user edits.
        self.input_sequence.extend(data)
        while self.input_sequence:
            if self.input_sequence[0] != 27:
                byte = self.input_sequence.pop(0)
                self.last_input = now
                if byte in (10, 13) and not self.pasting:
                    self.submitted = True
                else:
                    self.dirty = True
                    self.submitted = False
                continue
            match = re.match(
                rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)|P[^\x1b]*\x1b\\)",
                self.input_sequence,
            )
            if not match:
                if len(self.input_sequence) == 1 or self.input_sequence[:2] in (
                    b"\x1b[", b"\x1b]", b"\x1bP",
                ):
                    if len(self.input_sequence) < 4096:
                        break
                # Unknown Alt/escape input might restore or edit a draft.
                self.input_sequence.pop(0)
                self.last_input = now
                self.dirty = True
                self.submitted = False
                continue
            sequence = match.group()
            del self.input_sequence[:len(sequence)]
            color = re.fullmatch(
                rb"\x1b\](10|11);rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+)(?:\x07|\x1b\\)", sequence,
            )
            if color:
                # Scale X11's variable-width channels to the same 8-bit form
                # as colors.properties. Query replies never count as typing.
                channels = tuple(round(int(c, 16) * 255 / (16 ** len(c) - 1)) for c in color.groups()[1:])
                self.terminal_colors[int(color[1])] = channels
                if len(self.terminal_colors) == 2 and self.initial_terminal_colors is None:
                    self.initial_terminal_colors = dict(self.terminal_colors)
                continue
            if sequence == b"\x1b[200~":
                self.last_input = now
                self.pasting = True
            elif sequence == b"\x1b[201~":
                self.last_input = now
                self.pasting = False
            elif re.fullmatch(rb"\x1b\[13(?:;1(?::1)?)?u", sequence) and not self.pasting:
                self.last_input = now
                self.submitted = True
                continue
            elif sequence.startswith((b"\x1b]", b"\x1bP")) or re.fullmatch(
                rb"\x1b\[(?:[?>]?[0-9;]+[cR]|\??[0-9;]+\$y|[0-9;]+t|\?[0-9]+u|[0-9;]+:3u)", sequence,
            ):
                continue
            self.last_input = now
            self.dirty = True
            self.submitted = False

    def refresh_signature(self, current, baseline):
        """Watch displayed colors too, and wait for reload delivery before exit."""
        displayed_changed = (
            self.initial_terminal_colors is not None
            and self.terminal_colors != self.initial_terminal_colors
        )
        if current == baseline and not displayed_changed:
            return None
        if current is None:
            return (None, tuple(sorted(self.terminal_colors.items()))) if displayed_changed else None
        # When the terminal supports OSC queries, do not relaunch against an
        # old palette while the settings broadcast has not yet been delivered.
        for code, name in ((10, b"foreground"), (11, b"background")):
            match = re.search(rb"(?m)^\s*" + name + rb"\s*=\s*#([0-9a-fA-F]{6})\s*$", current)
            if match and code in self.terminal_colors:
                expected = tuple(bytes.fromhex(match[1].decode()))
                if self.terminal_colors[code] != expected:
                    return None
        return (current, tuple(sorted(self.terminal_colors.items())))

    def output(self, data, now):
        self.title_bytes.extend(data)
        while True:
            match = re.search(
                rb"\x1b\](?:0|2);([^\x07\x1b]*)(?:\x07|\x1b\\)",
                self.title_bytes,
            )
            if match is None:
                # Keep a potentially split OSC sequence, with a bounded buffer.
                del self.title_bytes[:-4096]
                return
            title = match[1].decode("utf-8", errors="replace")
            del self.title_bytes[:match.end()]
            title = title.lower()
            # Ready can be rendered before a resumed thread has attached. Require
            # its ID as well; Codex truncates full UUIDs in terminal titles.
            names = r"codex" if self.agent == "codex" else r"(?:traex|traecli|trae|traecode)"
            ready = re.fullmatch(
                names + r" \| ready \| ([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{5,12})(?:…|\.\.\.)?",
                title,
            )
            if ready:
                if self.thread_prefix != ready[1]:
                    self.ready_since = None
                self.thread_prefix = ready[1]
                if self.ready_since is None:
                    self.ready_since = now
            else:
                self.ready_since = None
                if re.match(names + r" \| (?:working|thinking)\b", title):
                    self.seen_work = True
                    if self.submitted:
                        self.dirty = False
                        self.submitted = False

    def can_quit(self, now, probe_empty=False):
        return (
            self.ready_since is not None
            and self.seen_work
            and now - self.ready_since >= 2
            and now - self.last_input >= 2
            and (not self.dirty or probe_empty)
            and not self.submitted
            and not self.pasting
            and not self.input_sequence
        )


def write_all(fd, data):
    while data:
        count = os.write(fd, data)
        data = data[count:]


def spawn_once(command, palette, baseline, agent="codex"):
    """Forward a real PTY, requesting graceful exit only after a safe state."""
    pid, master = pty.fork()
    if pid == 0:
        os.execvp(command[0], command)
    original = termios.tcgetattr(0)
    previous_handler = signal.getsignal(signal.SIGWINCH)
    tail = bytearray()
    gate = RestartGate(time.monotonic(), agent)
    gate.seen_work = "resume" in command[1:]
    requested = False
    request_deadline = None
    requested_theme = None
    requested_thread = None
    pending_theme = None
    theme_changed_at = None
    next_color_query = 0
    refused_input_at = None

    def resize(*_):
        try:
            import fcntl
            size = fcntl.ioctl(0, termios.TIOCGWINSZ, b"\0" * 8)
            fcntl.ioctl(master, termios.TIOCSWINSZ, size)
        except OSError:
            pass

    signal.signal(signal.SIGWINCH, resize)
    resize()
    try:
        tty.setraw(0)
        while True:
            # Leave typing buffered in the outer terminal once exit begins;
            # the resumed UI receives it after the child has exited.
            readable, _, _ = select.select([master] if requested else [0, master], [], [], 0.25)
            now = time.monotonic()
            if 0 in readable:
                data = os.read(0, 65536)
                if not data:
                    break
                gate.input(data, now)
                write_all(master, data)
            if master in readable:
                try:
                    data = os.read(master, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not data:
                    break
                write_all(1, data)
                tail.extend(data)
                del tail[:-65536]
                gate.output(data, now)
            if now >= next_color_query and not requested:
                write_all(1, b"\x1b]10;?\x07\x1b]11;?\x07")
                next_color_query = now + 5
            current = theme_signature(palette)
            refresh = gate.refresh_signature(current, baseline)
            if refresh is None:
                pending_theme = None
                theme_changed_at = None
            elif refresh != pending_theme:
                pending_theme = refresh
                theme_changed_at = now
            if (
                not requested
                and theme_changed_at is not None
                and now - theme_changed_at >= 2
                # Codex itself rejects Ctrl+D for a nonempty composer or popup;
                # delete-forward is remapped above, so this cannot erase a draft.
                # A stale conservative guard may remain after clearing input or
                # using a non-editing shortcut. Probe once per input revision.
                and (refused_input_at is None or gate.last_input != refused_input_at)
                and gate.can_quit(now, probe_empty=agent == "codex")
            ):
                write_all(master, b"\x04")
                requested = True
                requested_theme = current
                requested_thread = gate.thread_prefix
                request_deadline = now + 3
            elif requested and now >= request_deadline:
                # A restored draft or dialog can refuse Ctrl+D. Never repeat
                # it, clear the draft, kill the child, or force a timeout exit.
                requested = False
                refused_input_at = gate.last_input
                gate.dirty = True
    finally:
        termios.tcsetattr(0, termios.TCSADRAIN, original)
        signal.signal(signal.SIGWINCH, previous_handler)
        os.close(master)
    _, status = os.waitpid(pid, 0)
    return status, bytes(tail), requested, requested_theme, requested_thread


def palette_path():
    # Desktop and SSH sessions use actual terminal replies without a Termux
    # file. Android additionally waits for its settings reload to catch up.
    if Path("/system/bin/am").is_file():
        return Path.home() / ".termux/colors.properties"
    return None


def run(command, get_session_id, agent="codex"):
    options = resume_options(command, agent)
    palette = palette_path()
    baseline = theme_signature(palette)
    launch = [*command, *UI_OPTIONS]
    while True:
        status, output, requested, requested_theme, requested_thread = spawn_once(launch, palette, baseline, agent)
        exact_id = get_session_id(output)
        # Only our own successful graceful exit is eligible for auto-resume.
        # Manual exits, crashes, and missing exit hints remain normal exits.
        if (
            not requested
            or os.waitstatus_to_exitcode(status) != 0
            or not exact_id
            or not exact_id.lower().startswith(requested_thread)
        ):
            return status, output
        write_all(1, f"\r\n[{agent}: refreshing terminal theme; resuming this conversation]\r\n".encode())
        baseline = requested_theme
        launch = [command[0], *options, *UI_OPTIONS, *RECONNECT_OPTIONS, "resume", exact_id]
