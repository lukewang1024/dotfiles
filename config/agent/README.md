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
