# Global agent conventions

Single source of truth for every coding agent (Claude Code, Codex, opencode).
Canonical file: `~/.dotfiles/config/agent/AGENTS.md`, symlinked to each tool's
global instructions path (`~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md`);
`~/.claude/CLAUDE.md` imports it. Keep it tool-agnostic — all three read this.

## tmux task/window model — folding another repo into the task

You run inside a tmux **task session**: one session is one task, you (the agent)
are the driver living in the `agent` window, and each repo the task touches gets
its own inspection window (git/tig + shell).

When your work starts touching a **local repo other than the one you started in**:

1. Run `mux-inspect <absolute-repo-path>` once (via your shell tool). It adds that
   repo as an inspection window in the current tmux session, detached — it appears
   without stealing focus. Idempotent, so it is safe to re-run.
2. Bring the repo into your own **write** scope (the mechanism differs per agent):
   - **Claude Code** — `/add-dir <path>` (effective immediately).
   - **Codex** — you can already read it; to write there the session must be
     relaunched with `--add-dir <path>` (or add it to
     `sandbox_workspace_write.writable_roots` in `~/.codex/config.toml`).
   - **opencode** — approve the `external_directory` prompt on first access, or
     declare the path under `permission.external_directory` / `references`.

Do this the moment a repo enters scope, not at the end: the inspection window is
how the human follows your cross-repo work in real time.
