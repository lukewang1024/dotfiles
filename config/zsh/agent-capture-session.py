"""Run a CLI on a PTY and remember only its explicit exit session hint."""

import errno
import fcntl
import os
from pathlib import Path
import pty
import re
import signal
import sys
import termios

import agent_theme_restart


def session_id(output, agent="codex"):
    text = output.decode("utf-8", errors="replace")
    text = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", "", text)
    text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    uuid = r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"
    executable = r"codex" if agent == "codex" else r"(?:traex|traecli)"
    matches = re.findall(
        rf"(?:{executable} resume|Session ID:)\s+({uuid})\s*$", text, re.MULTILINE
    )
    return matches[-1] if matches else ""


def main():
    if sys.argv[1] == "--child":
        size, *command = sys.argv[2:]
        if size:
            fcntl.ioctl(0, termios.TIOCSWINSZ, bytes.fromhex(size))
        os.execvp(command[0], command)
    args = sys.argv[1:]
    agent = "codex"
    if args[:1] == ["--agent"]:
        agent, *args = args[1:]
    target, *command = args
    get_session_id = lambda output: session_id(output, agent)
    if agent_theme_restart.enabled(command, agent):
        status, output = agent_theme_restart.run(command, get_session_id, agent)
        Path(target).write_text(get_session_id(output), encoding="utf-8")
        code = os.waitstatus_to_exitcode(status)
        return code if code >= 0 else 128 - code
    tail = bytearray()
    master = None

    def resize(*_):
        if master is not None and os.isatty(sys.stdin.fileno()):
            try:
                size = fcntl.ioctl(sys.stdin.fileno(), termios.TIOCGWINSZ, b"\0" * 8)
                fcntl.ioctl(master, termios.TIOCSWINSZ, size)
            except OSError as error:
                if error.errno not in (errno.EBADF, errno.EIO):
                    raise

    def read_output(fd):
        nonlocal master
        if master is None:
            master = fd
            resize()
        data = os.read(fd, 65536)
        tail.extend(data)
        del tail[:-65536]
        return data

    signal.signal(signal.SIGWINCH, resize)
    size = ""
    if os.isatty(0):
        size = fcntl.ioctl(0, termios.TIOCGWINSZ, b"\0" * 8).hex()
    status = pty.spawn(
        [sys.executable, __file__, "--child", size, *command], master_read=read_output
    )
    Path(target).write_text(get_session_id(tail), encoding="utf-8")
    code = os.waitstatus_to_exitcode(status)
    return code if code >= 0 else 128 - code


if __name__ == "__main__":
    sys.exit(main())
