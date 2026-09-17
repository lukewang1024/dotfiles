# Repository Guidelines

## Structure

- `bootstrap/main.py`: shared Python 3.10+ standard-library entrypoint.
- `bootstrap/dotfiles/engine.py`: progress, logs, subprocesses, filesystem effects.
- `tasks.py`, `platforms.py`, `maintenance.py`: registered task definitions.
- `packages.json`, `links.json`, `macos-defaults.json`: declarative selections.
- `init` and `init.ps1`: thin source/runtime launchers. Do not add provisioning here.
- `config/`: tracked application configuration; `util/`: installed helper commands.

## Development

- Run `python3 -B -m unittest discover -s tests -v` (`python` on Windows).
- Inspect changes with `./init --dry-run --json --platform <platform> <mode>`.
- Platform is automatically detected for real runs: `./init core`, `./init sync`.
- Named tasks: `./init run pkg install_pip_packages core`; list with `--list-tasks`.
- Do not run full provisioning as a test on an existing user environment.
- Read `docs/bootstrap.md` for architecture and migration semantics.

## Style and effects

- Python: four spaces, UTF-8, standard library only, compatible with Python 3.10.
- New shell scripts use POSIX sh. Validate with `/bin/sh -n` and ShellCheck.
- Tasks use Context commands/filesystem helpers; keep reporting and redirection
  centralized in engine.py. Dry runs must not write files or execute commands.
- Honor XDG paths; executables belong in `~/.local/bin`.
- Do not commit secrets or machine-local overrides. Preserve user changes.
- Keep commits scoped. Describe affected platforms and actual validation in PRs.
