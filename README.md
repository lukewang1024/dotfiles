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
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" core
```

The platform is detected automatically. A mode is required.

### One bootstrap implementation

`init` (POSIX sh) and `init.ps1` (PowerShell 5.1/7) only locate the checkout,
prepare Python if necessary, and forward arguments and the exit code. All
provisioning and reporting run through `bootstrap/main.py`, using Python 3.10+
and the standard library. No Python packages need to be installed.

The launchers reuse an existing Python, or install managed Python 3.12 with uv
under XDG data/cache directories. Inspection commands never install a runtime.
A complete Git checkout is required; the standalone Windows launcher can clone
one when Git is already installed.

```sh
./init core --dry-run
./init --dry-run --json --platform windows all
./init --list-tasks
```

The same arguments work with `./init.ps1`. `--platform` is restricted to dry runs.
A dry run records intended actions without running commands, downloading files,
or writing configuration. Conditional actions reflect the inspected environment.

### Bootstrap progress and logs

On a terminal, one line shows the current category, nested step, running command,
and elapsed time. Each completed category becomes an `OK`, `SKIP`, or `FAIL` line.
At the end, the summary lists category results and any failed steps. Redirected
output uses plain progress lines without terminal escape codes.

The shared runner captures detailed stdout/stderr and checks command exit codes.
A required failure stops the run and returns a nonzero status. Optional actions
explicitly report that they need attention. Prompts and installers that require
a terminal temporarily use an interactive path; that interaction is not logged.

Each run creates `output.log` and `results.json` in:

- Unix: `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/bootstrap/<run>/`
- Windows: `$XDG_STATE_HOME/dotfiles/bootstrap/<run>/`, falling back to
  `$LOCALAPPDATA/State/dotfiles/bootstrap/<run>/`.

Unix run directories are private (`0700`), with logs created as `0600`. Follow
verbose output with `tail -f <log>` or `Get-Content <log> -Wait`.

All progress, logging, command execution, backup, and link behavior lives in
`bootstrap/dotfiles/engine.py`. Task modules use the shared context:

```python
@task()
def configure_tools(c):
    c.task('shell_setup')
    c.command('uv', 'tool', 'install', '--upgrade', 'example')
```

Package selections and links live in `packages.json` and `links.json`; macOS
preference commands live in `macos-defaults.json`. See the
[migration and maintenance guide](docs/bootstrap.md) for the module map.

Run the same harmless suite on each host (no application installation):

```sh
python3 -B -m unittest discover -s tests -v
```

```powershell
python -B -m unittest discover -s tests -v
```

The suite checks all seven platform plans, the previous package/link inventory,
stream routing, failure propagation, arguments, backups, migration, and terminal
rendering. On Windows it also exercises native scripts and both installed
PowerShell launchers.

Platform-specific prerequisites, side effects, and verification:

- [macOS setup](docs/platforms/macos.md)
- [Linux setup](docs/platforms/linux.md)
- [Termux setup](docs/platforms/termux.md)
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

`sync` refreshes links, wrappers, and XDG directories. It deliberately avoids
package/toolchain and plugin installation, prompts, network access, and `sudo`.

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
updates Alfred's configured preferences folder before removing the compatibility
path. If finalization fails, the compatibility link is kept so existing tools
remain usable. Re-running the migration safely finishes an interrupted or older
partial migration.

### Choose a provisioning mode

```text
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" <mode>
```

| Mode | Result |
| --- | --- |
| `basic` | Configure already-installed tools without installing platform packages. |
| `core` | Install the platform's baseline CLI and GUI environment, then configure it. |
| `all` | Install core plus platform extras, then configure it. |

Termux, ChromeOS, and Cygwin currently have no additional `all` package set;
they use their platform-specific core flow.

Other entrypoint tasks:

| Command | Result |
| --- | --- |
| `./init sync` | Reconcile an already-provisioned checkout. |
| `./init migrate-xdg [--dry-run]` | Move a legacy checkout to the XDG config root without breaking old links. |
| `./init machine-fabric` | Install or verify the local Machine Fabric runtime. |
| `./init npmg` | Reinstall common global npm packages. |
| `./init zinit` | Configure zinit and the tracked zsh startup files. |
| `./init run <module> <task> [arguments]` | Run a registered task; no shell evaluation. |

Frequently changing tmux workbench modules can be updated and re-applied as a
single clean-stack operation:

```sh
tmux-workbench-update --check
tmux-workbench-update
```

This fast-forwards `dotfiles`, `tmux-agent-workbench`, and
`tmux-adaptive-theme`, runs the dotfiles sync and workbench command installer,
then restarts the Workbench daemon and existing sidebar panes before reloading
a running tmux server. It refuses to start when any checkout has local changes,
avoiding a partially updated stack.

Machine Fabric is separate from the tmux workbench plugin. Use its own
`bootstrap-fabric.sh` with an exact release version and selected SSH nodes to
install or reconcile the multi-machine topology. The dotfiles entrypoint only
installs the local runtime when `MACHINE_FABRIC_VERSION` and
`MACHINE_FABRIC_RELEASE_BASE_URL` are set; otherwise it verifies an existing
`machine-fabric` installation. Machine Fabric v0.1.33 also supports Termux on
Android aarch64 through the same pinned installer path.

For example:

```sh
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" run macos-defaults better_macos_defaults
```

### Add or change configuration

1. Put application configuration in `config/<tool>/` or a reusable command in
   `util/`.
2. Add links to `bootstrap/dotfiles/links.json` and apply steps to the appropriate Python task.
3. Include it in `sync_setup` when existing machines need the new step.
4. Run `./init sync` and verify the destination link or merged block.
5. Confirm any replaced local file was preserved as `<path>~`.
6. Keep package-list changes separate from configuration changes in Git.

For launcher and helper shell changes, use `/bin/sh -n` and ShellCheck.
Run the shared Python suite and inspect the affected platform with `--dry-run`.

### Override a setting locally

These ignored files provide machine-local extension points:

- `$XDG_CONFIG_HOME/.rc.local` extends `config/sh/rc.sh`;
- `$XDG_CONFIG_HOME/.zshrc.local` extends `config/zsh/.zshrc`;
- `config/git/local` adds local Git configuration;
- `config/agent/hooks-keep.local.txt` retains private agent hooks;
- `config/agent/hooks-deny.local.txt` removes private hooks even when a keep
  rule also matches them;
- `config/agent/home-prune.local.tsv` lists private top-level HOME entries for
  `home-dotdir-prune` to archive.

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
