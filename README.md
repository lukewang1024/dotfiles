# Dotfiles

Personal development-environment configuration and bootstrap scripts for
macOS, Linux, and Windows.

This is an executable record of one environment, not a general-purpose
installer. Read the relevant platform guide before running it: provisioning can
install packages, invoke `sudo`, and change operating-system preferences.

## How it works

The repository separates desired configuration from the code that applies it:

```text
tracked source
├── config/      application and shell configuration
├── util/        commands installed into ~/.local/bin
└── bootstrap/   package installation, linking, and OS setup
        │
        ├── symlink ───────> application reads the tracked file directly
        ├── merge script ──> shared block inside a machine-local config
        └── setup action ──> package, directory, plugin, or OS state
```

Most application configuration is symlinked. This makes the repository the
source of truth and means a pulled content edit takes effect immediately.
Settings that must coexist with application-generated or machine-local state
are merged instead. Provisioning steps remain explicit and idempotent so they
can be reconciled safely.

Existing destinations are normally moved to a sibling ending in `~` before a
link replaces them. Secrets and machine-specific values stay outside tracked
files.

## Quick start

The Unix entrypoint expects the checkout at `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles`:

```sh
git clone https://github.com/lukewang1024/dotfiles "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" macos core
```

Use `debian` or `arch` instead of `macos` on Linux. Omitting the mode selects
`core`.

Platform-specific prerequisites, side effects, and verification:

- [macOS setup](docs/platforms/macos.md)
- [Linux setup](docs/platforms/linux.md)
- [Windows setup](docs/platforms/windows.md)

## Day-to-day operations

### Update an existing machine

```sh
cd "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
git pull
```

The tracked `post-merge` hook runs `./init sync` when provisioning files change.
It can also be run explicitly:

```sh
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" sync
```

`sync` refreshes links, wrappers, plugins, shared agent settings, and XDG
directories. It deliberately avoids package/toolchain installation, prompts,
and `sudo`.

### Migrate a legacy checkout

Machines that still have a real checkout at `~/.dotfiles` can preview and apply
an XDG migration in place:

```sh
~/.dotfiles/init migrate-xdg --dry-run
~/.dotfiles/init migrate-xdg
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" sync
```

The migration refuses to overwrite an existing target, moves the repository to
`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles`, temporarily creates a
`~/.dotfiles` compatibility symlink, atomically retargets managed links, and
then removes the compatibility path. If finalization fails, the compatibility
link is kept so existing tools remain usable. Re-running the migration safely
finishes an interrupted or older partial migration.

### Choose a provisioning mode

```text
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" <platform> [mode]
```

| Mode | Result |
| --- | --- |
| `core` | Baseline CLI and GUI environment; the default. |
| `cli` | Baseline plus the extended CLI toolset. |
| `gui` | Baseline plus the extended desktop-app set. |
| `all` | Both extended CLI and GUI flows. |
| `game` | Platform-specific gaming tools where supported. |

Unix-like selectors are `macos` (`osx`), `debian`, `arch`, `chromeos`, and
`cygwin`. ChromeOS and Cygwin have dedicated flows rather than the complete mode
matrix.

Other entrypoint tasks:

| Command | Result |
| --- | --- |
| `./init basic` | Apply the shared shell and development baseline without a platform package flow. |
| `./init sync` | Reconcile an already-provisioned checkout. |
| `./init migrate-xdg [--dry-run]` | Move a legacy checkout to the XDG config root without breaking old links. |
| `./init npmg` | Reinstall common global npm packages. |
| `./init zinit` | Configure zinit and the tracked zsh startup files. |
| `./init run <module> <function>` | Run one function from a bootstrap module. |

For example:

```sh
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" run macos-defaults better_macos_defaults
```

### Add or change configuration

1. Put application configuration in `config/<tool>/` or a reusable command in
   `util/`.
2. Add its linking or apply step to the appropriate `bootstrap/` module.
3. Include it in `sync_setup` when existing machines need the new step.
4. Run `./init sync` and verify the destination link or merged block.
5. Confirm any replaced local file was preserved as `<path>~`.
6. Keep package-list changes separate from configuration changes in Git.

For shell changes, use `/bin/sh -n` for POSIX scripts and `bash -n` for the Bash
bootstrap modules. Run ShellCheck when available.

### Override a setting locally

These ignored files provide machine-local extension points:

- `$XDG_CONFIG_HOME/.rc.local` extends `config/sh/rc.sh`;
- `$XDG_CONFIG_HOME/.zshrc.local` extends `config/zsh/.zshrc`;
- `config/git/local` adds local Git configuration;
- `config/agent/hooks-keep.local.txt` retains private agent hooks.

Do not commit tokens, SSH keys, workplace credentials, or per-machine paths.

## Storage model

The shell setup follows the XDG base-directory convention:

| Location | Ownership |
| --- | --- |
| `~/.config` | Configuration |
| `~/.local/share` | Persistent application data |
| `~/.local/state` | Logs, history, and state |
| `~/.cache` | Re-downloadable or disposable caches |
| `~/.local/bin` | User executables |

`config/sh/xdg-ninja-patch.sh` relocates tools that would otherwise put state at
the top level of `$HOME`.

## Repository map

| Path | Responsibility |
| --- | --- |
| `init`, `init.ps1` | Unix-like and Windows entrypoints |
| `bootstrap/` | Package sets, setup functions, and platform defaults |
| `config/` | Tracked source-of-truth configuration |
| `util/` | Reusable commands linked into `~/.local/bin` |
| `shell/` | Standalone shell support files |
| `docs/platforms/` | Platform prerequisites and operating procedures |

Tool-level documentation is intentionally selective. A tool gets its own
README when it has generated/merged state, multiple cooperating components, or
a non-obvious install and recovery workflow. Plain upstream configuration does
not need a second description that can drift from the file itself.

Current subsystem guides include:

- [shared coding-agent configuration](config/agent/README.md)
- [Alfred workflows](config/AlfredApp/README.md)
- [Rime configuration](config/Rime/README.md)
