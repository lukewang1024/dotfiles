#!/usr/bin/python3
"""Alfred Script Filter for the `dark` keyword.

Offers a toggle plus the two explicit targets, and — because the whole point of
this workflow is that the OS switch drives a fan-out — reports whether that
fan-out is actually wired up on this machine, rather than leaving the human to
guess why nvim didn't follow.

Pinned to /usr/bin/python3 (system 3.9): `python3` on PATH is a pyenv shim that
Alfred's environment does not reliably resolve. No 3.10+ syntax.
"""

import glob
import json
import os
import subprocess
import sys


def current():
    """Return 'dark' or 'light' for the current system appearance."""
    # `defaults read` exits non-zero when the key is absent, which IS the light
    # case — absence is the signal, so a failed read is not an error here.
    try:
        out = subprocess.run(
            ["defaults", "read", "-g", "AppleInterfaceStyle"],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return "light"
    return "dark" if "dark" in out.strip().lower() else "light"


def relay_status():
    """Describe what will follow the switch, for the toggle row's subtitle."""
    parts = []
    daemon = (
        subprocess.run(
            ["launchctl", "list", "com.lukew.appearance"],
            capture_output=True,
        ).returncode
        == 0
    )
    if daemon:
        parts.append("nvim, Alacritty")
    else:
        # Without the daemon nothing is watching, so apply.sh drives theme-sync
        # itself. Say so — a silent fallback is how you end up debugging the
        # wrong layer six months later.
        parts.append("via theme-sync fallback (appearance-daemon not loaded)")

    boxes = len(glob.glob(os.path.expanduser("~/.ssh/tmux-*.sock")))
    if boxes:
        parts.append("%d devbox%s" % (boxes, "" if boxes == 1 else "es"))
    return ", ".join(parts)


def main():
    cur = current()
    other = "light" if cur == "dark" else "dark"
    follows = relay_status()

    items = [
        {
            "uid": "toggle",
            "title": "Switch to %s" % other.capitalize(),
            "subtitle": "Currently %s — %s follow" % (cur.capitalize(), follows),
            "arg": "toggle",
            "icon": {"path": "icon.png"},
            "match": "toggle switch %s" % other,
        }
    ]
    for name in ("light", "dark"):
        active = name == cur
        items.append(
            {
                "uid": name,
                "title": name.capitalize(),
                "subtitle": "Already %s" % name if active else "Force %s" % name,
                "arg": name,
                "icon": {"path": "icon.png"},
                "match": name,
            }
        )

    json.dump({"items": items}, sys.stdout)


if __name__ == "__main__":
    main()
