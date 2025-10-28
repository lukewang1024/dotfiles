# Repository Guidelines

## Project Structure & Module Organization
- bootstrap: OS-specific setup scripts (e.g., `macos.sh`, `debian.sh`, `arch.sh`, `pkg.sh`).
- config: Dotfiles and app configs to be symlinked into `$HOME`/`$XDG_CONFIG_HOME` (e.g., `config/zsh`, `config/git`, `config/i3`).
- util: Helper scripts grouped by OS (`util/macos`, `util/linux`, etc.).
- init: Unix entrypoint; `init.ps1`: Windows entrypoint. See examples below.

## Build, Test, and Development Commands
- Run on macOS: `~/.dotfiles/init macos [core|cli|gui|all]` — install runtimes, apps, and apply defaults.
- Run on Linux: `~/.dotfiles/init debian|arch [core]` — install packages and set up configs for the distro.
- Run package set: `~/.dotfiles/init npmg` — install common global npm packages.
- Invoke a specific function: `~/.dotfiles/init run macos-defaults better_macos_defaults` — source a partial and run a function.
- Windows bootstrap: in PowerShell, `./init.ps1 core` from the repo root.

## Coding Style & Naming Conventions
- Indentation: spaces, size 2; LF endings; UTF‑8 (see `.editorconfig`).
- Shell: prefer POSIX sh where feasible; Bash is acceptable in `bootstrap/*.sh`.
- Naming: use lowercase with dashes for scripts (`macos-defaults.sh`), and directory-per-tool under `config/<tool>`.
- Linting: if available, run `shellcheck` on changed scripts.

## Testing Guidelines
- Dry-run by targeting a VM or fresh user account first.
- After `init` runs, verify key links exist (e.g., `~/.config/zsh`, `~/Library/Rime`).
- For macOS, confirm Homebrew installs and defaults applied; for Linux, confirm package manager steps complete.

## Commit & Pull Request Guidelines
- Commits: imperative, concise, scoped (e.g., "macos: add rectangle config", "zsh: speed up prompt").
- PRs: include OS/distro, what changed, why, and validation steps; attach screenshots for UI tweaks where useful.
- Keep changes atomic: config updates separate from package lists; avoid committing machine-specific secrets.

## Security & Configuration Tips
- Do not commit tokens, SSH keys, or per-machine overrides.
- Use local overrides instead of editing tracked files: `$XDG_CONFIG_HOME/.rc.local`, `$XDG_CONFIG_HOME/.zshrc.local`.
