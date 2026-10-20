"""Refresh supported agent TUIs after a terminal palette change on POSIX."""

import errno
import os
from pathlib import Path
import pty
import re
import select
import signal
import struct
import sys
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
    "--scene", "--adjust",
}
FLAG_OPTIONS = {
    "--yolo", "--dangerously-bypass-approvals-and-sandbox", "--approve-for-me",
    "--dangerously-bypass-hook-trust", "--no-alt-screen", "--search",
    "--strict-config", "--oss",
}
RESUME_FLAGS = {"--last", "--all", "--include-non-interactive"}
THEME_WATCH_RETRY_SECONDS = 30
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
        # tmux dims the default foreground when a pane loses focus. That is
        # not a palette reload: use the background for terminal-only changes
        # and debounce, retaining foreground replies for file verification.
        displayed_changed = (
            self.initial_terminal_colors is not None
            and self.terminal_colors.get(11) != self.initial_terminal_colors.get(11)
        )
        displayed = (self.terminal_colors[11],) if 11 in self.terminal_colors else ()
        if current == baseline and not displayed_changed:
            return None
        if current is None:
            return (None, displayed) if displayed_changed else None
        # When the terminal supports OSC queries, do not relaunch against an
        # old palette while the settings broadcast has not yet been delivered.
        for code, name in ((10, b"foreground"), (11, b"background")):
            match = re.search(rb"(?m)^\s*" + name + rb"\s*=\s*#([0-9a-fA-F]{6})\s*$", current)
            if match and code in self.terminal_colors:
                expected = tuple(bytes.fromhex(match[1].decode()))
                if self.terminal_colors[code] != expected:
                    return None
        return (current, displayed)

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


class ThemeNotifications:
    """Watch atomic appearance-file replacements with Linux inotify."""

    def __init__(self, path):
        import ctypes
        self.path = path
        self.value = self.read()
        if self.value not in {b"light", b"dark"}:
            raise OSError("No published appearance; keep terminal polling")
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "inotify_init1")
        # Watch the directory: publishers replace the file with an atomic mv.
        # CLOSE_WRITE | MOVED_TO | CREATE | DELETE | DELETE_SELF | MOVE_SELF
        mask = 0x8 | 0x80 | 0x100 | 0x200 | 0x400 | 0x800
        if libc.inotify_add_watch(self.fd, os.fsencode(path.parent), mask) < 0:
            self.close()
            raise OSError(ctypes.get_errno(), "inotify_add_watch")

    def read(self):
        try:
            with self.path.open("rb") as stream:
                return stream.read(64).strip()
        except OSError:
            return None

    def drain(self):
        relevant = False
        invalid = False
        while True:
            try:
                data = os.read(self.fd, 65536)
            except BlockingIOError:
                break
            offset = 0
            while offset + 16 <= len(data):
                _, mask, _, length = struct.unpack_from("iIII", data, offset)
                name = data[offset + 16:offset + 16 + length].split(b"\0", 1)[0]
                offset += 16 + length
                relevant |= name == os.fsencode(self.path.name)
                # Overflow, removed/moved directory or lost watch: fall back.
                invalid |= bool(mask & (0x4000 | 0x400 | 0x800 | 0x8000))
        if invalid:
            raise OSError("Appearance watch lost")
        value = self.read() if relevant else self.value
        changed = value != self.value
        self.value = value
        return changed

    def close(self):
        os.close(self.fd)


def theme_notifications(palette, on_error=None):
    # Termux still verifies its palette reload; unsupported hosts keep polling.
    if palette is not None or not os.environ.get("TMUX") or not sys.platform.startswith("linux"):
        return None
    path = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "appearance"
    try:
        return ThemeNotifications(path)
    except (OSError, AttributeError) as error:
        if on_error is not None:
            on_error(error)
        return None


class ColorReplies:
    """Consume our OSC replies without stealing child queries or user input."""

    def __init__(self):
        self.pending = set()
        self.buffer = bytearray()

    def queried(self):
        self.pending.update((10, 11))

    def forward(self, data):
        self.buffer.extend(data)
        result = bytearray()
        while self.buffer:
            match = re.match(
                rb"\x1b\](10|11);rgb:[0-9a-fA-F]+/[0-9a-fA-F]+/[0-9a-fA-F]+(?:\x07|\x1b\\)",
                self.buffer,
            )
            if match and int(match[1]) in self.pending:
                self.pending.remove(int(match[1]))
                del self.buffer[:match.end()]
                continue
            # Reads can split anywhere, including between ESC and ST's slash.
            partial = any(
                prefix.startswith(self.buffer) or (
                    self.buffer.startswith(prefix)
                    and re.fullmatch(rb"[0-9a-fA-F/]*(?:\x1b)?", self.buffer[len(prefix):])
                )
                for prefix in (f"\x1b]{code};rgb:".encode() for code in self.pending)
            )
            if partial and len(self.buffer) < 4096:
                break
            result.append(self.buffer.pop(0))
        return bytes(result)


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
    color_replies = ColorReplies()
    watch_retry_at = None

    def watch_unavailable(error):
        nonlocal watch_retry_at
        if watch_retry_at is None:
            write_all(2, (
                f"\r\n[{agent}: theme watch unavailable ({error}); polling; "
                f"retrying every {THEME_WATCH_RETRY_SECONDS:g}s]\r\n"
            ).encode())
        watch_retry_at = time.monotonic() + THEME_WATCH_RETRY_SECONDS

    notifications = theme_notifications(palette, watch_unavailable)
    confirmation_until = 0
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
            now = time.monotonic()
            deadlines = []
            if requested and request_deadline is not None:
                deadlines.append(request_deadline)
            elif not requested and next_color_query is not None:
                deadlines.append(next_color_query)
            if not requested and watch_retry_at is not None:
                deadlines.append(watch_retry_at)
            if (
                not requested and theme_changed_at is not None
                and (refused_input_at is None or gate.last_input != refused_input_at)
                and gate.can_quit(now + 2, probe_empty=agent == "codex")
            ):
                deadlines.append(max(theme_changed_at + 2, gate.ready_since + 2, gate.last_input + 2))
            timeout = max(0, min(deadlines) - now) if deadlines else None
            readers = [master] if requested and request_deadline is not None else [0, master]
            if notifications is not None:
                readers.append(notifications.fd)
            readable, _, _ = select.select(readers, [], [], timeout)
            now = time.monotonic()
            if notifications is not None and notifications.fd in readable:
                try:
                    changed = notifications.drain()
                except OSError as error:
                    notifications.close()
                    notifications = None
                    watch_unavailable(error)
                    changed = True
                if changed:
                    # theme-sync publishes before repainting tmux. Debounce and
                    # confirm a few times to cover that asynchronous apply.
                    next_color_query = now + 2
                    confirmation_until = now + 17
            if 0 in readable:
                data = os.read(0, 65536)
                if not data:
                    requested = False
                    break
                previous_input = gate.last_input
                gate.input(data, now)
                if requested and gate.last_input != previous_input:
                    # A later manual exit must not be mistaken for our probe.
                    requested = False
                forwarded = color_replies.forward(data)
                if forwarded:
                    write_all(master, forwarded)
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
            if not requested and watch_retry_at is not None and now >= watch_retry_at:
                watch_retry_at = now + THEME_WATCH_RETRY_SECONDS
                notifications = theme_notifications(palette, watch_unavailable)
                if notifications is not None:
                    watch_retry_at = None
                    write_all(2, f"\r\n[{agent}: theme watch restored]\r\n".encode())
                    # A mode change may have happened while the watch was down.
                    # Verify the displayed palette before returning to idle.
                    next_color_query = now + 2
                    confirmation_until = now + 17
            if next_color_query is not None and now >= next_color_query and not requested:
                color_replies.queried()
                write_all(1, b"\x1b]10;?\x07\x1b]11;?\x07")
                next_color_query = now + 5 if notifications is None or now < confirmation_until else None
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
            elif requested and request_deadline is not None and now >= request_deadline:
                # A restored draft or dialog can refuse Ctrl+D. Never repeat
                # it, clear the draft, kill the child, or force a timeout exit.
                # Slow shutdown is not evidence that Ctrl+D was refused.
                # Accept input again, but retain our exit identity until real
                # user input cancels it. Never send a second probe meanwhile.
                request_deadline = None
                refused_input_at = gate.last_input
                gate.dirty = True
    finally:
        if notifications is not None:
            notifications.close()
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
