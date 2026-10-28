# Shared coding-agent configuration

This directory is the tracked, machine-independent source of truth for coding
agents. `./init sync` installs the entrypoints and applies the managed settings.

- `AGENTS.md` contains instructions shared by Claude Code, Codex, and OpenCode.
- `claude-settings.json` is deep-merged into `~/.claude/settings.json` by
  `claude-settings-apply`. Unmanaged keys such as hooks, permissions, model, and
  machine-local state are preserved.
- `codex-tui.toml` owns the marked UI block inside `[tui]` in
  `~/.codex/config.toml`. Alternate screen uses Codex's default; syncing removes
  the previously managed override. The terminal title uses the readable thread
  title and task progress. The theme-refresh wrapper verifies an exit's exact
  session ID against thread-name metadata rather than displaying that ID.
  Raw output mode remains a manual toggle.
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

### Codex scenes and teams

`agent-team/config/teams.json` is the shared source for daily, hard, batch and
computer (电脑自动化) Codex scenes. Single and Team select the same scene, and
Fast is scene-wide. Use:

```sh
agent start codex --scene daily
agent start codex --scene hard --team
agent start codex --scene batch --team --tmux
agent start codex --scene computer
```

The computer scene selects GPT-6.1 Terra max for Single, Team lead and workers,
with Fast off. It uses the existing computer-use skills and desktop tools.

The `agent` entrypoint is supplied by tmux-agent-workbench and delegates scene
resolution to `agent-team start codex`. `codex` defaults to daily Single after
`codex-settings-apply`; `codex-team` starts daily Team and supports `--scene`.
`codex-yolo` adds explicit YOLO to daily Single. Old expert/budget shortcuts
and their Team variants are removed without aliases.

`codex-settings-apply` reads the daily scene plan from agent-team, applies its
model, effort, Fast and Single defaults to local Codex config while preserving
unmanaged settings and comments, and archives retired writable Team profiles
under `$XDG_STATE_HOME/agent-team/retired-profiles`. Shared profile templates
are no longer seeded. Machine-local scene overrides belong in
`$XDG_CONFIG_HOME/agent-team/config.json`, under `codex.scenes`.

The implementation, adapters and collaboration protocol remain in the standalone
`~/Code/github/agent-team` checkout. `./init core` installs it; `./init sync`
applies lightweight settings. Native and tmux Team modes remain opt-in and
never mix. Other tools keep their existing presets, including `traex-budget`.
The shared AGENTS.md references the standalone collaboration rules.

- `code-ship` and `skills/code-ship` implement repository shipping policies.
  First use asks for a strategy and saves it under XDG config, never in the
  repository. Run `agent-skills-install --local-only` to install local skills
  without downloading other skills. The command requires Python 3; GitHub PRs
  and auto-merges require authenticated `gh`. Organization-specific providers
  are installed separately and selected in the machine-local policy.

- [`codex-reset-card`](skills/codex-reset-card/SKILL.md) queries Codex quota reset
  credits and schedules one selected credit with a Linux user systemd timer.
  It also documents status, cancellation and outcome verification. Scripts and
  instructions live here; account login, proxy settings, task configurations and
  receipts stay in machine-local XDG directories. Run
  `agent-skills-install --local-only` to install this skill alongside `code-ship`
  without network access.
  Installing skills does not enable timers or redeem credits.

- `agent-skills-install` also installs the public interview skills from
  `mattpocock/skills` for Claude Code, Codex, and OpenCode. Install the complete
  bundle: `grill-me` delegates to `grilling`; `grill-with-docs` delegates to
  `grilling` and `domain-modeling` (including its document templates). The
  installer checks all four skills before skipping an existing installation.
  Keep their names in `skills-keep.txt` so `agent-skills-prune --apply` preserves
  the dependencies. Run `agent-skills-install` to repair an incomplete bundle.
