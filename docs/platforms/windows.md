# Windows setup

Windows uses the same Python bootstrap as macOS and Linux. `init.ps1` only
locates the source and Python runtime; package managers, Windows settings,
linking, progress, and logs are implemented under `bootstrap/dotfiles/`.

## Design

Package selections live in `packages.jsonc`, configuration links in `links.json`,
and Windows operations in `platforms.py`. Scoop and WinGet remain the Windows
package managers. PowerShell snippets are used for Windows APIs and vendor
installers; they do not duplicate the task graph or reporter.

| Mode | Includes |
| --- | --- |
| `basic`, `sync` | Supported application links and repository hook configuration |
| `core` | Core CLI and GUI packages, then Windows configuration |
| `cli` | Core plus extended CLI packages |
| `gui` | Core plus extended GUI packages, then Windows configuration |
| `all` | Extended CLI and GUI flows |
| `game` | Gaming-specific packages |

## Install a new machine

Use PowerShell 5.1 or 7. The launcher ensures Scoop is available, installs Git
through Scoop when a standalone checkout needs it, and installs Scoop's latest
Python package before handing control to `bootstrap/main.py`.

```powershell
$configRoot = $env:XDG_CONFIG_HOME
if (!$configRoot) { $configRoot = Join-Path $env:USERPROFILE '.config' }
$repo = Join-Path $configRoot 'dotfiles'
git clone https://github.com/lukewang1024/dotfiles $repo
Set-Location $repo
.\init.ps1 core --dry-run
.\init.ps1 core
```

If the machine needs an HTTP proxy during bootstrap, pass it explicitly. The
launcher does not detect or require a particular proxy client:

```powershell
.\init.ps1 --proxy http://proxy.example:8118 core
```

The proxy flag is consumed by `init.ps1`, applied to Scoop, and omitted from
the arguments forwarded to `bootstrap/main.py`. Without the flag, no proxy is
configured by the launcher.

Alternatively, download `init.ps1` into a temporary directory. With Git available,
it clones the source into the same config location. It refuses to overwrite an
incomplete destination. Inspection commands require a complete checkout and an
existing Python runtime.

Application links use the actual checkout path, including existing legacy
checkouts; they no longer assume `%USERPROFILE%\.dotfiles`. Configuration may
request elevation, enable Developer Mode, and configure the OpenSSH agent.
Symbolic links require Developer Mode or an elevated session.

## Update and reconcile

```powershell
Set-Location $repo
git pull
.\init.ps1 sync
```

`sync` refreshes links and the repository hook without package installation,
prompts, or elevation. Existing linked content changes take effect immediately.
It requires the symlink permissions already established by initial provisioning.

## Verify

```powershell
python -B -m unittest discover -s tests -v
.\init.ps1 --dry-run --json all
Get-Command scoop
Get-Command winget
Get-Item $env:APPDATA\alacritty
Get-Item $env:USERPROFILE\Documents\PowerShell
Get-Item $env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
Get-Service ssh-agent
```

Also verify Git's Windows OpenSSH setting and the Rime, SSH, and Tig links.
Detailed output and `results.json` use `$XDG_STATE_HOME/dotfiles/bootstrap/`, or
`$LOCALAPPDATA/State/dotfiles/bootstrap/` when XDG state is unset.

## Backups

The shared linker moves an existing file/directory to a sibling ending in `~`.
If that backup already exists, it uses a unique `.backup-<timestamp>` sibling.
Inspect these files before restoring a destination. An already-correct symlink
is left in place.
