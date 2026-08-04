#!/usr/bin/env python3
"""Shared helpers for the Amphetamine workflow's Script Filters.

Stdlib only, and kept compatible with the system interpreter (/usr/bin/python3,
3.9 on macOS) because Alfred's PATH does not reliably resolve the pyenv shim.
"""
import json
import os
import plistlib
import subprocess
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLIST = HERE / "info.plist"
LOG = Path(os.path.expanduser("~/.local/state/amphetamine-alfred.log"))

KEYWORD_TYPES = ("alfred.workflow.input.keyword", "alfred.workflow.input.scriptfilter")

# Sentinels returned by `session time remaining`, per Amphetamine.sdef.
NO_SESSION = -3
APP_OR_DATE_SESSION = -2
TRIGGER_SESSION = -1
INFINITE_SESSION = 0

# One round-trip fetches every state field; issuing eight separate osascript
# calls made the Script Filter visibly laggy.
_STATE_SCRIPT = """with timeout of 4 seconds
tell application "Amphetamine"
\tset r to {}
\tset end of r to (session is active) as text
\tset end of r to (session time remaining) as text
\tset end of r to (session is Trigger) as text
\tset end of r to (display sleep allowed) as text
\tset end of r to (screen saver allowed) as text
\tset end of r to (closed display mode enabled) as text
\tset end of r to (Triggers are enabled) as text
\tset end of r to (Drive Alive is enabled) as text
\tset AppleScript's text item delimiters to "|"
\treturn r as text
end tell
end timeout"""

_STATE_FIELDS = (
    "active",
    "remaining",
    "is_trigger",
    "display_sleep_allowed",
    "screen_saver_allowed",
    "closed_display_mode",
    "triggers_enabled",
    "drive_alive_enabled",
)


def amphetamine_running():
    return subprocess.run(
        ["/usr/bin/pgrep", "-x", "Amphetamine"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def read_state():
    """Current Amphetamine state, or None if unavailable.

    Returns None when Amphetamine is not running rather than talking to it, so
    that merely asking for status never launches the app as a side effect.
    """
    if not amphetamine_running():
        return None
    try:
        proc = subprocess.run(
            ["/usr/bin/osascript", "-e", _STATE_SCRIPT],
            capture_output=True,
            text=True,
            timeout=8,
        )
    except (subprocess.TimeoutExpired, OSError):
        return None
    if proc.returncode != 0:
        return None

    parts = proc.stdout.strip().split("|")
    if len(parts) != len(_STATE_FIELDS):
        return None

    state = {}
    for name, raw in zip(_STATE_FIELDS, parts):
        if name == "remaining":
            try:
                state[name] = int(raw)
            except ValueError:
                return None
        else:
            state[name] = raw == "true"
    return state


def human_duration(seconds):
    hours, minutes = divmod((int(seconds) + 59) // 60, 60)
    if hours and minutes:
        return "{}h {}m".format(hours, minutes)
    if hours:
        return "{}h".format(hours)
    return "{}m".format(minutes)


def session_headline(state):
    """(title, subtitle) describing the session in one row."""
    if state is None:
        return "Amphetamine is not running", "Launch it, then run a command"

    secs = state["remaining"]
    if secs == NO_SESSION:
        return "No active session", "Your Mac sleeps normally"
    if secs == APP_OR_DATE_SESSION:
        return "Session active", "App-based or date-based session"
    if secs == TRIGGER_SESSION:
        return "Session active", "Trigger-based session"
    if secs == INFINITE_SESSION:
        return "Session active — indefinite", "No end time set"
    return (
        "Session active — {} left".format(human_duration(secs)),
        "Ends on its own",
    )


def usage_stats():
    """Invocation count and last-used timestamp per command label, from the log."""
    counts = {}
    last = {}
    try:
        lines = LOG.read_text(errors="replace").splitlines()
    except OSError:
        return counts, last

    for line in lines:
        if "invoked" not in line:
            continue
        parts = line.split(None, 2)
        if len(parts) < 2 or not parts[1].startswith("["):
            continue
        label = parts[1].strip("[]")
        counts[label] = counts.get(label, 0) + 1
        last[label] = parts[0]
    return counts, last


def ago(stamp):
    try:
        then = time.mktime(time.strptime(stamp, "%Y-%m-%dT%H:%M:%S"))
    except (ValueError, TypeError):
        return None
    delta = max(0, int(time.time() - then))
    if delta < 90:
        return "just now"
    if delta < 3600:
        return "{}m ago".format(delta // 60)
    if delta < 86400:
        return "{}h ago".format(delta // 3600)
    return "{}d ago".format(delta // 86400)


def commands():
    """Every keyword this workflow defines, in info.plist order."""
    data = plistlib.loads(PLIST.read_bytes())
    out = []
    for obj in data.get("objects", []):
        if obj.get("type") not in KEYWORD_TYPES:
            continue
        config = obj.get("config", {})
        keyword = config.get("keyword")
        if not keyword:
            continue

        # argumenttype 2 == takes no argument. A Script Filter's argument filters
        # its own rows rather than setting a session duration.
        if config.get("argumenttype", 2) == 2:
            arg_hint = ""
        elif obj["type"] == "alfred.workflow.input.scriptfilter":
            arg_hint = "[filter]"
        else:
            arg_hint = "[duration]"

        out.append(
            {
                "keyword": keyword,
                # Keyword inputs title with 'text'; Script Filters use 'title'.
                "title": config.get("text") or config.get("title") or keyword,
                "subtext": config.get("subtext") or "",
                "arg_hint": arg_hint,
            }
        )
    return out


def log_invocation(label):
    """Keep the Script Filters in the same usage stats the AppleScripts feed."""
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as fh:
            fh.write("{} [{}] invoked\n".format(time.strftime("%Y-%m-%dT%H:%M:%S"), label))
    except OSError:
        pass


def emit(items, rerun=None):
    payload = {"items": items}
    if rerun:
        payload["rerun"] = rerun
    print(json.dumps(payload))
