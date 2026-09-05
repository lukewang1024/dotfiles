# Global agent conventions

Single source of truth for every coding agent (Claude Code, Codex, opencode).
Canonical file: `$XDG_CONFIG_HOME/dotfiles/config/agent/AGENTS.md`, symlinked to each tool's
global instructions path (`~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`);
`~/.claude/CLAUDE.md` imports it. Keep it tool-agnostic — all three read this.

## tmux task/window model — folding another repo into the task

Some tmux sessions are **task workbenches**: one session is one task, you (the
agent) are the driver living in the `agent` window, and each repo the task
touches gets its own inspection window (git/tig + shell). Such a session is
marked with `@workbench_task` by the workbench launcher. You may equally be
running in an **ordinary** session (a bare agent the human started ad-hoc);
there, this whole mechanism stays out of the way and you do nothing special
for cross-repo work.

Use the public `tmux-agent-workbench` command for all workbench operations.
Legacy command aliases are compatibility-only; do not use them in new calls.

When your work starts touching a **local repo other than the one you started in**:

1. First check whether you're in a **workspace** session — its root (and every
   repo already folded in) lives under `~/Workspace/<feature>/...` rather than
   directly under `~/Code`. That's a multi-repo task: each member repo is its
   own git worktree/branch dedicated to this feature, not just a read-only
   peek at the repo's shared `~/Code` checkout.
   - **Workspace session, repo not yet a member** — run
     `tmux-agent-workbench add <repo-short-name>[:<branch>]` (e.g. `tmux-agent-workbench add web-app`) instead of
     `tmux-agent-workbench inspect`. It creates that repo's worktree under this workspace
     (branch defaults to the workspace's own name) *and* folds it in as an
     inspection window in one step. Idempotent — re-running it once the
     worktree exists just re-focuses the window.
   - **Any other session** (an ordinary single-repo session from the `~/Code`
     pool, or a workspace repo that's already a member) — `tmux-agent-workbench inspect
     <absolute-repo-path>` as below.
2. Run `tmux-agent-workbench inspect <absolute-repo-path>` once (via your shell tool) — either
   directly (non-workspace case) or as the last step `tmux-agent-workbench add` already took care
   of. In a workbench it adds that repo as an inspection window in the current
   session, detached — it appears without stealing focus. Idempotent and safe
   to re-run. It **self-gates**: in an ordinary (non-workbench) session it
   simply no-ops, so you can call it unconditionally without worrying about
   which kind of session you are in — no need to detect the session type
   yourself.
3. Bring the repo into your own **write** scope (the mechanism differs per agent):
   - **Claude Code** — `/add-dir <path>` (effective immediately).
   - **Codex** — you can already read it; to write there the session must be
     relaunched with `--add-dir <path>` (or add it to
     `sandbox_workspace_write.writable_roots` in `~/.codex/config.toml`).
   - **opencode** — approve the `external_directory` prompt on first access, or
     declare the path under `permission.external_directory` / `references`.

Do this the moment a repo enters scope, not at the end: the inspection window is
how the human follows your cross-repo work in real time. None of this needs to
be decided up front — a workspace can start (`tmux-agent-workbench new <feature>`) with zero
repos attached and grow into whichever ones the task actually turns out to
touch, one `tmux-agent-workbench add` at a time.

When a task needs a dev server or another long-running command, keep the default
inspection window unchanged until the command is actually needed. Then run
`tmux-agent-workbench run --name <label> <absolute-repo-path> -- <command> <args...>`.
For commands that require shell syntax, use
`tmux-agent-workbench run --name <label> <absolute-repo-path> --shell '<command>'`.
It appends a
detached task pane to that repo's inspection window, starts the command, and
prints the pane id. Use that pane id with `tmux capture-pane` to inspect output
or `tmux kill-pane` when the task is no longer needed. Do not run persistent
project processes in the session-level agent pane.

Missing `TMUX` / `TMUX_PANE` variables do not prove that this is an ordinary
session: agent tool runners may remove them. The command can recover the
session through process ancestry. If a PID sandbox hides that too, use
`WORKBENCH_SESSION=<verified-session-name-or-id>` with the public command.
For `add`, `WORKBENCH_FEATURE=<verified-workspace-name>` is also supported.
If tmux socket access is denied, use the agent's permission mechanism to retry
with socket access. Do not treat a connection or session-resolution failure
as permission to launch the task in an independent background process.

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
