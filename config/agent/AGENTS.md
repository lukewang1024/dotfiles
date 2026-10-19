# Global agent conventions

Single source of truth for every coding agent (Claude Code, Codex, opencode).
Canonical file: `$XDG_CONFIG_HOME/dotfiles/config/agent/AGENTS.md`, symlinked to each tool's
global instructions path (`~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`);
`~/.claude/CLAUDE.md` imports it. Keep it tool-agnostic — all three read this.

## Opt-in agent teams

When session instructions state "Team delegation mode is enabled", proactively
use the selected team mode for useful independent subtasks. Follow the shared
collaboration rules injected by the standalone `agent-team` CLI. Without this
explicit opt-in, this section does not enable delegation. The standalone
repository owns the full protocol; do not duplicate it here.

Native mode uses native subagents only. An explicit `agent-team --tmux` session
uses interactive pane workers only in its dedicated team window. This is the
exception to the ordinary workbench/dev-server pane rules below; do not alter
repository inspection windows or mix native and pane workers in one team.

## tmux workbench conventions

Before operating tmux windows, agents, workspaces, or persistent dev servers, run
`tmux-agent-workbench conventions` and follow its instructions. Workbench owns
these rules; keep this file as a reference rather than duplicating them here.

## Computer-use window cleanup

Application windows, documents, dialogs, and browser tabs opened or created by
the agent are task resources. Close them when their use is finished and before
reporting the task complete, unless the user explicitly asks to leave them open.
This includes Microsoft Word documents opened for inspection, editing, rendering,
and verification. Delivering a file does not imply leaving its application window open.

Record the existing windows/documents/tabs before starting, and track those the
task creates or opens. Reuse task-owned windows where practical rather than
accumulating new ones. Preserve the user's pre-existing windows and unrelated
work; close individual task-owned resources rather than quitting the whole app.

Save requested outputs to their intended paths and verify the saves before
closing their windows. Discard unsaved changes only in known disposable test or
scratch documents. Never discard user edits or an unidentified unsaved document.
If ownership or save status is uncertain, preserve that resource and report the
specific cleanup blocker instead of silently leaving it behind.

Perform cleanup on successful completion and on failure or cancellation when
control is still available. Verify that task-owned resources have closed; do not
treat issuing a close command as proof. If the user explicitly requested that a
resource remain open, identify what was kept open in the final handoff.

## Proxy inheritance for agent-initiated processes

When this machine has an HTTP proxy configured, pass it to the **actual process
environment** of agent-initiated commands that need network access, including
commands that create, start, or resume background work. Child processes and
independently launched workers must inherit it too. Carry `HTTP_PROXY`,
`HTTPS_PROXY`, and `ALL_PROXY` in both uppercase and lowercase forms, plus
`NO_PROXY` / `no_proxy` when configured. Apply this throughout the launch and
continuation flow, including any step that may start execution implicitly.

Read the existing machine-local proxy configuration or inherited environment;
never hard-code proxy addresses or credentials in this file or a repository.
Check presence in the launch environment and, when diagnosing a failure, in
the resulting worker processes. Report only whether variables are present,
never their values. Configuration in one application does not automatically
configure independently launched processes. If the required variables are
missing, fix the launch environment before retrying the work.

## Where generated files go — keep `$HOME` clean, honour XDG

The human keeps `$HOME` tidy: most tool state is redirected into XDG dirs via
`$XDG_CONFIG_HOME/dotfiles/config/sh/xdg-ninja-patch.sh` (`XDG_CONFIG_HOME=~/.config`,
`XDG_DATA_HOME=~/.local/share`, `XDG_STATE_HOME=~/.local/state`,
`XDG_CACHE_HOME=~/.cache`). When you create files, follow the same rule:

- **Executables / scripts / launchd (or systemd) wrappers** go in `~/.local/bin`
  (already on `PATH`). **Never create `~/bin`** — it is not on `PATH` and only
  clutters `$HOME`. A launchd `plist` `ProgramArguments` should point at
  `~/.local/bin/<name>` or directly at the source script, not at `~/bin`.
- **Config** → `$XDG_CONFIG_HOME`; **data** → `$XDG_DATA_HOME`; **logs / state /
  history** → `$XDG_STATE_HOME`; **caches / re-downloadable artifacts** →
  `$XDG_CACHE_HOME`. Do not drop new top-level dirs directly in `$HOME`.
- If a tool hard-codes a `$HOME`-root path you cannot configure, prefer a symlink
  from that path into the right XDG dir over leaving a real dir in `$HOME`.
- When a tool supports an env var to relocate its dir (`FOO_HOME`, `*_CACHE_DIR`,
  goenv `GOENV_GOPATH_PREFIX`, puppeteer `PUPPETEER_CACHE_DIR`, …), add the export
  to `xdg-ninja-patch.sh` rather than accepting the `$HOME`-root default.

## Shell scripts — POSIX sh, not bash

New shell scripts are **POSIX `sh`** (`#!/bin/sh`), not bash. They must run
under a strict POSIX shell and in a minimal environment (e.g. a launchd/systemd
job with no `LANG` and a bare `PATH`), so don't assume bash or a login shell.

- Avoid bashisms: no `[[ … ]]`, `local`, arrays, `$'…'`, `${var:offset:len}`,
  `<<<`, `read -d/-t/-u`, process substitution. Use `case`, `printf`, `cut`,
  `stty`/`dd` for byte-wise reads, `expr`/`$(( ))` for arithmetic.
- Don't name a function after a POSIX special built-in (`set`, `read`, `test`,
  `eval`, …) — under POSIX the built-in wins and the function is never called
  (a bash-only footgun). Name helpers `t`, `opt`, etc.
- Validate with `sh -n script` (syntax) and mentally with `dash`/`set -u`.
- Verified with `/bin/sh -n`; keep executables in `~/.local/bin` per above.

Exceptions: vendored third-party code keeps its upstream interpreter, and a
compiled helper (Swift/Go/…) is fine when a shell genuinely can't do the job.

## Private machine-local instructions

Read `$XDG_CONFIG_HOME/agent/AGENTS.local.md` when it exists (use
`~/.config/agent/AGENTS.local.md` when XDG_CONFIG_HOME is unset).
Keep personal publishing identities, account/profile mappings, and other private
machine policy in that local file outside this repository. Never copy its
contents into tracked files, commits, pull requests, or public logs.
