# Amphetamine — Alfred workflow

Control [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) from
Alfred. Originally "Amphetamine Control" by William C. Gustafson (2016, bundle id
`com.gustafson.william`), rewritten here for Amphetamine 5.x.

## Commands

| Keyword | Effect |
| --- | --- |
| `amphetamine on [duration]` | Start a session; indefinite when no duration is given |
| `amphetamine off` | End the current session |
| `amphetamine toggle [duration]` | End the session if one is active, otherwise start one |
| `amphetamine status` | Session state, sleep settings and Triggers; ↩ toggles the session |
| `amphetamine help` | Command reference, duration formats and usage stats |

Durations accept `30m`, `2h`, `1h 30m`, `1h30m`, `1 hour 30 minutes`, a bare
number as minutes (`90`), or two bare numbers as hours then minutes (`1 30`).

### `status` (`status.py`)

Reports what Amphetamine is doing right now: the session headline (indefinite,
time remaining, Trigger-based, app/date-based or none), whether display sleep and
the screen saver are allowed — for the running session, or as the default for new
ones — plus the closed-display-mode, Triggers and Drive Alive switches. The view
sets `rerun: 2` so a timed session counts down in place.

Only the headline row is actionable; it is wired to the same toggle action as
`amphetamine toggle`, so ↩ flips the session. Detail rows are deliberately
`valid: false` so they can't fire the toggle by accident (⌘C still copies them).

If Amphetamine isn't running, `status` says so rather than querying it — asking
for status should never launch the app.

### `help` (`help.py`)

A Script Filter rather than static text: it lists the keywords by reading this
workflow's own `info.plist`, so the help can't drift from the real commands —
adding a keyword makes it appear here for free. Rows are ordered by how often each
command has actually been used, taken from the log. ↩ copies a command to the
clipboard.

`lib.py` holds what both filters share: the single-round-trip state query (eight
separate `osascript` calls made the filter visibly laggy), keyword parsing, log
parsing and Alfred JSON output.

## Install

Nothing to run. Alfred's sync folder is `~/.dotfiles/config/AlfredApp`, and
`Alfred.alfredpreferences/workflows/user.workflow.amphetamine` is a repo-relative
symlink back to this directory — both are tracked, so a fresh clone is already
wired up. See `../README.md`.

Alfred caches `info.plist` in memory, so **restart Alfred** after changing it:

```sh
osascript -e 'tell application "Alfred 5" to quit'; open -a "Alfred 5"
```

`help.py` is read live on each run and needs no restart.

## Notes for future edits

Amphetamine 5.x scripting has two traps that cost real debugging time:

- The 3.x verbs `turn on` / `turn off` are **gone** — use `start new session` /
  `end session`. Scripts using the old verbs fail to *compile*, and Alfred
  swallows the error, so the workflow appears to do nothing at all.
- `displaySleepAllowed` is **mandatory** in the `with options` record even though
  `Amphetamine.sdef` presents the record as optional and its own example omits
  it. Leaving it out fails with `AppleEvent handler failed (-10000)`.
  `start new session` with no options at all is fine (it uses app preferences).

Also worth knowing:

- `interval:` takes AppleScript's own constants — `minutes` is 60, `hours` is
  3600; `duration:0, interval:0` means indefinite. The sdef declares no
  enumeration for it.
- `session time remaining` returns `-3` for no session, `-2` app/date-based,
  `-1` Trigger-based, `0` infinite.
- Script Filters call `/usr/bin/python3` explicitly: `python3` on `PATH` is a
  pyenv shim that Alfred's environment does not reliably resolve. That pins the
  scripts to the system interpreter (3.9), so no 3.10+ syntax.
- Amphetamine exposes no URL scheme and no Shortcuts/App Intents actions —
  AppleScript is the only automation surface.

Every invocation is logged to `~/.local/state/amphetamine-alfred.log`, and
failures raise a notification carrying the AppleScript error number. Apple events
are wrapped in a 10s timeout so a wedged Amphetamine fails visibly instead of
hanging for AppleScript's 120s default.

The pristine 2018 `info.plist` is kept outside the repo at
`~/.local/state/amphetamine-alfred-info.plist.orig`.
