# Windows setup

Windows provisioning is implemented in `init.ps1`. It installs packages through
Scoop and WinGet, clones this repository, enables required Windows features, and
links supported application configuration.

## Design

Windows uses a separate PowerShell entrypoint because its package managers,
privilege model, paths, and symbolic-link behavior differ from the Unix setup.
It still follows the same source-of-truth rule: tracked files live under
`%USERPROFILE%\.dotfiles\config`, while applications read linked destinations.

| Mode | Includes |
| --- | --- |
| `core` | Core CLI and GUI packages |
| `cli` | Core plus extended CLI packages |
| `gui` | Core plus extended GUI packages |
| `all` | Extended CLI and GUI flows |
| `game` | Gaming-specific packages |

The package lists are personal and extensive. Review the selected functions in
`init.ps1` before running them.

## Install a new machine

Download the entrypoint into the user profile and run it from PowerShell:

```powershell
Set-Location $env:USERPROFILE
Invoke-WebRequest `
  -Uri https://raw.githubusercontent.com/lukewang1024/dotfiles/master/init.ps1 `
  -OutFile $env:USERPROFILE\init.ps1
.\init.ps1 core
```

During configuration, the script clones the repository to
`%USERPROFILE%\.dotfiles`. It may request elevation, enable Developer Mode, and
configure the OpenSSH agent. Developer Mode is required for the intended
symbolic-link workflow.

## Update

There is currently no Windows equivalent of the Unix `./init sync` task or its
post-merge hook. Pull tracked content directly:

```powershell
Set-Location $env:USERPROFILE\.dotfiles
git pull
```

Changes to already-linked files take effect through the symlink. When a pull
adds a new linking or provisioning step, rerun the appropriate `init.ps1` mode
after reviewing its package and system actions.

## Verify

```powershell
git -C $env:USERPROFILE\.dotfiles status --short
Get-Command scoop
Get-Command winget
Get-Item $env:APPDATA\alacritty
Get-Item $env:USERPROFILE\Documents\PowerShell
Get-Item $env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
Get-Service ssh-agent
```

Also verify that Git uses Windows OpenSSH and that the linked Rime, SSH, and Tig
configuration is visible to their applications.

## Recover an overwritten destination

The PowerShell linker uses the same backup convention as Unix: an existing
destination is moved to a sibling ending in `~`. Inspect the link and backup
before restoring either one:

```powershell
Get-Item $env:APPDATA\alacritty
Get-Item "$env:APPDATA\alacritty~"
```
