# Global agent conventions

Single source of truth for every coding agent (Claude Code, Codex, opencode).
Canonical file: `~/.dotfiles/config/agent/AGENTS.md`, symlinked to each tool's
global instructions path (`~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`);
`~/.claude/CLAUDE.md` imports it. Keep it tool-agnostic — all three read this.

## tmux task/window model — folding another repo into the task

Some tmux sessions are **task workbenches**: one session is one task, you (the
agent) are the driver living in the `agent` window, and each repo the task
touches gets its own inspection window (git/tig + shell). Such a session is
launched via `mux-agent`, which stamps it with a `@mux_task` marker. You may
equally be running in an **ordinary** session (a bare agent the human started
ad-hoc); there, this whole mechanism stays out of the way and you do nothing
special for cross-repo work.

When your work starts touching a **local repo other than the one you started in**:

1. Run `mux-inspect <absolute-repo-path>` once (via your shell tool). In a
   workbench it adds that repo as an inspection window in the current session,
   detached — it appears without stealing focus. Idempotent and safe to re-run.
   It **self-gates**: in an ordinary (non-workbench) session it simply no-ops, so
   you can call it unconditionally without worrying about which kind of session
   you are in — no need to detect the session type yourself.
2. Bring the repo into your own **write** scope (the mechanism differs per agent):
   - **Claude Code** — `/add-dir <path>` (effective immediately).
   - **Codex** — you can already read it; to write there the session must be
     relaunched with `--add-dir <path>` (or add it to
     `sandbox_workspace_write.writable_roots` in `~/.codex/config.toml`).
   - **opencode** — approve the `external_directory` prompt on first access, or
     declare the path under `permission.external_directory` / `references`.

Do this the moment a repo enters scope, not at the end: the inspection window is
how the human follows your cross-repo work in real time.

## Where generated files go — keep `$HOME` clean, honour XDG

The human keeps `$HOME` tidy: most tool state is redirected into XDG dirs via
`~/.dotfiles/config/sh/xdg-ninja-patch.sh` (`XDG_CONFIG_HOME=~/.config`,
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
