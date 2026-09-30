# Shared coding-agent configuration

This directory is the tracked, machine-independent source of truth for coding
agents. `./init sync` installs the entrypoints and applies the managed settings.

- `AGENTS.md` contains instructions shared by Claude Code, Codex, and OpenCode.
- `claude-settings.json` is deep-merged into `~/.claude/settings.json` by
  `claude-settings-apply`. Unmanaged keys such as hooks, permissions, model, and
  machine-local state are preserved.
- `codex-tui.toml` owns the marked UI block inside `[tui]` in
  `~/.codex/config.toml`, with `alternate_screen = "never"` to preserve terminal
  scrollback for tmux copying. Raw output mode remains a manual toggle.
  `codex-settings-apply` also removes two known ignored
  settings from existing configs: `profiles.<name>.review_model` and
  `projects.<path>.sandbox_mode`. Other local settings and comments are preserved.
  Set the review model at the top level, and sandbox policy at the top level,
  in a supported profile, or in project-local `.codex/config.toml`.
- `claude-statusline` is installed in `~/.local/bin` and discovers Node and the
  latest installed claude-hud version without embedding a username or OS path in
  Claude's settings.

Do not add credentials, per-project permissions, MCP secrets, or absolute
machine-specific paths to these shared files.

### Codex shortcuts

Plain `codex` uses the model and effort in the local Codex config. The
`agent-team` checkout installs `codex-budget` (GPT-6 Luna Max for bounded,
low-cost tasks) and `codex-expert` (GPT-6 Astra Medium for demanding work) as
solo CLI wrappers. The zsh integration calls them through the same approval and
resume-history helper as plain `codex`. These Codex model shortcuts do not imply
`--yolo`; pass it explicitly when needed. The `codex-team` and `codex-team-budget`
commands below launch separate, opt-in team presets.
The `traex-budget` CLI wrapper uses the same installer and keeps its
TraeX-specific GPT-5.6 Luna High and `--yolo` settings. The zsh integration
also records its resume command.

### Agent teams

The implementation, adapters, collaboration protocol and tests live in the
standalone `~/Code/github/agent-team` checkout. `./init core` clones or updates
that checkout and links its commands into `~/.local/bin`; set `AGENT_TEAM_REPO`
for a different checkout location. `agent-team-install` can be run directly
to repair the entrypoints. `./init sync` only installs this helper and applies
the lightweight configuration links. `tmux-workbench-update` also fetches,
fast-forwards, and reinstalls agent-team alongside the tmux workbench stack.

Run `agent-team` to select a coding agent and preset, or `agent-team --tmux` for
interactive pane teams. Tool-specific shortcuts such as `codex-team` are owned
by the standalone installer. The shared AGENTS.md only authorizes the opt-in
mode; the standalone CLI injects the full collaboration rules.

The standalone `agent-team/config/teams.json` owns Team, Team Budget, Codex solo
budget/expert, and TraeX solo budget presets. Direct shortcuts use
`agent-team solo codex budget`, `agent-team solo codex expert`, and
`agent-team solo traex budget`. Machine-local overrides belong in
`$XDG_CONFIG_HOME/agent-team/config.json`.

Personal Codex defaults remain in `team.config.toml` and
`team-budget.config.toml` as initialization templates. `codex-settings-apply`
seeds independent files in `${CODEX_HOME:-~/.codex}` and converts the old
symlinks into regular files, preserving existing trust and local settings.
Existing regular profiles are never overwritten by sync. They remain compatible
with direct `codex --profile` use, but `agent-team` launches pass the resolved
model and reasoning settings explicitly. Codex may write project trust to these
runtime profiles; those paths must never be linked back into dotfiles.
The standalone CLI can also
run without these profiles using its bundled defaults. Machine-local overrides
for any supported tool belong in `$XDG_CONFIG_HOME/agent-team/config.json`.

- `code-ship` and `skills/code-ship` implement repository shipping policies.
  First use asks for a strategy and saves it under XDG config, never in the
  repository. Run `agent-skills-install --local-only` to install local skills
  without downloading other skills. The command requires Python 3; GitHub PRs
  and auto-merges require authenticated `gh`. Organization-specific providers
  are installed separately and selected in the machine-local policy.

- `agent-skills-install` also installs the public interview skills from
  `mattpocock/skills` for Claude Code, Codex, and OpenCode. Install the complete
  bundle: `grill-me` delegates to `grilling`; `grill-with-docs` delegates to
  `grilling` and `domain-modeling` (including its document templates). The
  installer checks all four skills before skipping an existing installation.
  Keep their names in `skills-keep.txt` so `agent-skills-prune --apply` preserves
  the dependencies. Run `agent-skills-install` to repair an incomplete bundle.
