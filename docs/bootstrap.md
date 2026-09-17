# Shared bootstrap implementation

All seven platform flows now run Python 3.10+ standard-library code. The old
`bootstrap/*.sh` modules and separate PowerShell provisioning implementation
have been removed. Installed utilities under `util/` and upstream installers
retain their native interpreters.

## Source map

| Source | Responsibility |
| --- | --- |
| `init`, `init.ps1` | Locate source/Python, prepare a runtime if needed, forward argv and exit status |
| `bootstrap/main.py` | Shared executable entry |
| `bootstrap/dotfiles/cli.py` | Modes, platform detection/override, category selection |
| `bootstrap/dotfiles/engine.py` | Task progress, log capture, process exit codes, filesystem operations, dry runs |
| `bootstrap/dotfiles/tasks.py` | Common environment, shells, editors, language tools, configuration |
| `bootstrap/dotfiles/platforms.py` | Native packages/settings, Termux and workbench integration |
| `bootstrap/dotfiles/maintenance.py` | Kerberos, XDG migration, standalone task compositions |
| `bootstrap/dotfiles/packages.json` | Package groups extracted from previous shell/PowerShell arrays |
| `bootstrap/dotfiles/links.json` | Previous declarative links |
| `bootstrap/dotfiles/macos-defaults.json` | macOS preference command arguments |

Old module names remain accepted by `run` for common maintenance commands:

```sh
./init run pkg install_pip_packages core
./init run macos-defaults better_macos_defaults
./init --list-tasks
```

`run` selects registered Python tasks. Arbitrary shell expressions and private
shell helpers are no longer an API. Module names identify the legacy namespace;
platform-specific module names must match the current platform.

## Adding behavior

Register a task with `@task()`, call children with `c.task(name, ...)`, and execute
commands with `c.command(*argv)`. Arguments are passed as data without shell
interpolation. Use `c.link`, `c.write`, `c.download`, and other context methods so
plans and actual runs have the same operation boundaries. Keep terminal output,
stream redirection, and process handling in the engine.

`c.command` checks exit status by default. For an intentionally optional action,
use `check=False` and handle its return value explicitly. Use `Skip` for a step
that does not apply. An unhandled failure stops the run; the summary and JSON
record the failing child and category. Interactive commands must explicitly use
`interactive=True`; their terminal interaction is not captured. Homebrew cask
installs use this mode because package installers can request sudo authentication.
Captured sudo commands retain the controlling terminal's session so they can
reuse the credentials established by interactive authentication.

macOS personalization preferences are optional: each rejected write prints a
`Preference not applied` note and records `SKIP` in `results.json`, while the
remaining preferences continue. Protected settings may require terminal privacy
permissions or manual changes in System Settings. Package installation and
required setup commands still fail the run on error. LaunchServices maintenance
uses garbage collection and app registration refresh; the removed `-kill` option
is no longer used.

A dry run skips effects, including command execution and network access. It
still reads local configuration and evaluates conditions, so a plan is an
inspection of the current environment, not a promise of successful provisioning.

## Deliberate migration changes

- One progress renderer, log format, task runner, and command boundary on all OSes.
- Every run writes `output.log` and UTF-8 `results.json`; required failures stop
  later categories instead of allowing a later successful command to mask them.
- Windows gains configuration-only `basic` and `sync`, uses the actual checkout location,
  and supports the same inspection flags and named tasks as Unix.
- Python is the shared runtime. Launchers reuse 3.10+ or prepare managed 3.12 with
  uv; inspection does not install it. A standalone Windows launcher needs Git
  to retrieve the checkout. Cygwin requires a Cygwin-native Python installation.
- When running on Homebrew Python, child commands retain its formula through
  `HOMEBREW_NO_CLEANUP_FORMULAE` for this run (preserving existing exclusions).
  Upgrades can proceed, but cleanup cannot delete the running interpreter's
  standard library. A later ordinary Homebrew cleanup can remove the old keg.
- Existing backup files are retained; replacements get a unique backup name.
- SSH uses a private regular `~/.ssh/config` entrypoint on Unix and Windows.
  Bootstrap replaces its managed Include block while preserving third-party
  additions and existing local content. It backs up legacy symlinks before
  replacing them, so CloudIDE and similar tools can no longer write through to
  the repository. `~/.ssh/config.local` is included before the shared
  `config/ssh/config`; local values take precedence over shared defaults.
  `Host *` resets isolate the includes from preceding Host/Match blocks.
  The legacy link inventory is retained, but SSH entries dispatch to this setup.
  To migrate or refresh just SSH, run `./init run shell ssh_setup`.
- Linux inotify settings use a dedicated sysctl drop-in. macOS Launchpad reset
  uses its reset preference instead of deleting system cache trees.
- XDG migration is implemented in Python. `util/dotfiles/migrate-xdg` is only a
  compatibility launcher. Interrupted migrations retain the compatibility link.

The preserved package and link inventory is checked against
`tests/fixtures/bootstrap-inventory.json`, updated through upstream `768c9bf`.
The migration includes the newer Hyper Linux dependencies/links and macOS
Rectangle shortcut migration. This verifies data preservation;
external package availability and installer behavior still need platform testing.

## Verification

```sh
python3 -B -m unittest discover -s tests -v
/bin/sh -n init
/bin/sh -n util/dotfiles/migrate-xdg
./init --dry-run --json --platform macos all
```

On Windows, run the same suite with `python`. It additionally verifies `.cmd`
and `.ps1` failure propagation and both installed PowerShell launcher versions.
Tests use temporary directories and never install application packages. A real
full provisioning run is a separate acceptance check on a disposable machine.

### Migration verification

Validated on Linux with Python 3.14, on `cndevboxgui` with Python 3.12 and
Windows PowerShell 5.1/7.6, and on `MacBook-Pro` (arm64, macOS 26.6.2) with
Homebrew Python 3.14.7. All three hosts passed their applicable shared tests,
including isolated file/link operations. The Mac run passed 23 tests and skipped
5 Windows-only tests. It also exercised native `defaults` and `PlistBuddy` on a
temporary plist and launcher discovery with a minimal PATH and no LANG.
The launcher now finds Homebrew Python even when the system Python is too old. All seven platform
`basic`, `core`, `all`, and `sync` plans were checked without effects. POSIX
launchers passed `sh -n` and ShellCheck.

This validation did not install the full application sets or exercise a fresh
machine's Python download. Full application provisioning and system preference
changes were not applied to the Mac. Arch, ChromeOS, Termux, and Cygwin still
need live acceptance on their respective systems.

On 2026-09-17, a full `./init core` acceptance run on macOS 26.6.2 completed
with exit status 0: CLI core, GUI core, and Homebrew cleanup all passed.
Of 221 personalization writes, 170 succeeded and 51 were rejected and recorded
as `SKIP` (Safari 36, Mail 9, universal access 5, Address Book 1). This confirms
installation completion, not that every preference took effect. The system's
`cfprefsd` log identified the universal-access rejection as missing sandbox
write access. Granting terminal privacy permissions or applying settings
manually remains necessary for those protected preferences.
