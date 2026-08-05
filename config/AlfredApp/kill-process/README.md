# Kill Process

Type `kill` followed by a process name to find and force-quit a running
process. Press Return to kill the selected PID, or Command-Return to kill every
process with the same executable name.

This is Nathan Greenstein's Kill Process 1.2 workflow, restored from the
upstream release after the original local copy was retired during the 2026-08
Alfred cleanup.

- Upstream: <https://github.com/nathangreenstein/alfred-process-killer>
- Bundle ID: `com.ngreenstein.alfred-process-killer`
- License: WTFPL, as declared by the upstream project

The workflow uses macOS's system Ruby, `ps`, `kill`, and `killall`; it has no
third-party runtime dependencies. The source of truth is this directory. The
tracked relative symlink under `Alfred.alfredpreferences/workflows/` makes it
available to Alfred on every machine using this dotfiles checkout.
