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


def session_id(output):
    text = output.decode("utf-8", errors="replace")
    text = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", "", text)
    text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    uuid = r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}"
    matches = re.findall(
        rf"(?:codex resume|Session ID:)\s+({uuid})\s*$", text, re.MULTILINE
    )
    return matches[-1] if matches else ""


def main():
    if sys.argv[1] == "--child":
        size, *command = sys.argv[2:]
        if size:
            fcntl.ioctl(0, termios.TIOCSWINSZ, bytes.fromhex(size))
        os.execvp(command[0], command)
    target, *command = sys.argv[1:]
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
    Path(target).write_text(session_id(tail), encoding="utf-8")
    code = os.waitstatus_to_exitcode(status)
    return code if code >= 0 else 128 - code


if __name__ == "__main__":
    sys.exit(main())
