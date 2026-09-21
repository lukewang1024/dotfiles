# Shared coding-agent configuration

This directory is the tracked, machine-independent source of truth for coding
agents. `./init sync` installs the entrypoints and applies the managed settings.

- `AGENTS.md` contains instructions shared by Claude Code, Codex, and OpenCode.
- `claude-settings.json` is deep-merged into `~/.claude/settings.json` by
  `claude-settings-apply`. Unmanaged keys such as hooks, permissions, model, and
  machine-local state are preserved.
- `codex-tui.toml` owns the marked UI block inside `[tui]` in
  `~/.codex/config.toml`. `codex-settings-apply` preserves every other setting.
- `claude-statusline` is installed in `~/.local/bin` and discovers Node and the
  latest installed claude-hud version without embedding a username or OS path in
  Claude's settings.

Do not add credentials, per-project permissions, MCP secrets, or absolute
machine-specific paths to these shared files.

### Agent teams

The implementation, adapters, collaboration protocol and tests live in the
standalone `~/Code/github/agent-team` checkout. Run `agent-team-install` to link
its commands into `~/.local/bin`; set `AGENT_TEAM_REPO` for a different checkout
location. `./init sync` installs this helper and the personal Codex profiles,
not the implementation. No checkout is cloned automatically.

Run `agent-team` to select a coding agent and preset, or `agent-team --tmux` for
interactive pane teams. Tool-specific shortcuts such as `codex-team` are owned
by the standalone installer. The shared AGENTS.md only authorizes the opt-in
mode; the standalone CLI injects the full collaboration rules.

Personal Codex defaults remain in `team.config.toml` and
`team-budget.config.toml`, linked into `~/.codex/`. The standalone CLI can also
run without these profiles using its bundled defaults. Machine-local overrides
for any supported tool belong in `$XDG_CONFIG_HOME/agent-team/config.json`.

- `code-ship` and `skills/code-ship` implement repository shipping policies.
  First use asks for a strategy and saves it under XDG config, never in the
  repository. Run `agent-skills-install --local-only` to install local skills
  without downloading other skills. The command requires Python 3; GitHub PRs
  additionally require authenticated `gh`. Organization-specific providers are
  installed separately and selected in the machine-local policy.

- `agent-skills-install` also installs the public interview skills from
  `mattpocock/skills` for Claude Code, Codex, and OpenCode. Install the complete
  bundle: `grill-me` delegates to `grilling`; `grill-with-docs` delegates to
  `grilling` and `domain-modeling` (including its document templates). The
  installer checks all four skills before skipping an existing installation.
  Keep their names in `skills-keep.txt` so `agent-skills-prune --apply` preserves
  the dependencies. Run `agent-skills-install` to repair an incomplete bundle.
