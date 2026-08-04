#!/usr/bin/env python3
"""Script Filter behind `amp status`.

Shows what Amphetamine is doing right now: the session headline first, then the
sleep-related settings in force and the Trigger / Drive Alive switches. The view
re-runs every 2s so a timed session counts down in place.

Actioning the headline toggles the session; other rows copy their text.
"""
import lib


def build_items(state):
    title, subtitle = lib.session_headline(state)

    if state is None:
        return [{"uid": "state", "title": title, "subtitle": subtitle, "valid": False}]

    active = state["remaining"] != lib.NO_SESSION
    items = [
        {
            "uid": "state",
            "title": title,
            # The headline is the only actionable row: this Script Filter is wired
            # straight to the toggle action, so ↩ flips the session. The detail
            # rows below are marked invalid so they can't fire it by accident —
            # ⌘C still copies their text.
            "subtitle": subtitle + "   ·   ↩ to " + ("end it" if active else "start one"),
            "arg": "",
            "valid": True,
            "text": {"copy": title},
        }
    ]

    # Scope matters: with a session running these describe that session; with no
    # session they are the defaults future sessions will inherit.
    scope = "this session" if active else "default for new sessions"

    def detail(uid, text, subtitle_text):
        items.append(
            {
                "uid": uid,
                "title": text,
                "subtitle": subtitle_text,
                "valid": False,
                "text": {"copy": text},
            }
        )

    def onoff(label, enabled, on_text, off_text):
        return label + ": " + (on_text if enabled else off_text)

    detail(
        "display",
        onoff("Display sleep", state["display_sleep_allowed"], "allowed", "prevented"),
        scope,
    )
    detail(
        "saver",
        onoff("Screen saver", state["screen_saver_allowed"], "allowed", "prevented"),
        scope,
    )

    for uid, label, enabled in (
        ("cdm", "Closed-display mode", state["closed_display_mode"]),
        ("triggers", "Triggers", state["triggers_enabled"]),
        ("drivealive", "Drive Alive", state["drive_alive_enabled"]),
    ):
        detail(uid, onoff(label, enabled, "enabled", "disabled"), "app-wide setting")

    if state["is_trigger"]:
        items.append(
            {
                "uid": "trigger",
                "title": "Current session came from a Trigger",
                "subtitle": "Ending it may restart immediately unless Triggers are disabled",
                "valid": False,
            }
        )

    return items


if __name__ == "__main__":
    state = lib.read_state()
    items = build_items(state)
    lib.log_invocation("status")
    # Re-run so a countdown stays honest while the view is open.
    lib.emit(items, rerun=2 if state is not None else None)
