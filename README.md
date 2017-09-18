# Dotfiles and Bootstrap Scripts

## Installation

```bash
$ cd ~
$ git clone https://github.com/lukewang1024/dotfiles .dotfiles # Has to be `.dotfiles`
$ ~/.dotfiles/init macos # Bootstrap MacOS CLI environment
```

## Usage

```
./init [platform] [option]
List of platforms:
  macos | osx - MacOS
  wsl         - Default WSL with Ubuntu (CLI only)
  alwsl       - Custom WSL with Arch Linux (CLI only)
  cygwin      - Cygwin
  ubuntu      - Ubuntu
  arch        - Arch Linux
List of options:
  cli - Prepare CLI environment only (default)
  gui - Prepare GUI environment only
  all - Prepare both environments
Other tasks:
  npmg - Install global npm packages (in case of version switch in nvm)
```

- Create a file in `~/.rc.local` to override configs from `~/.dotfiles/config/shared/rc.sh`.
- Create a file in `~/.zshrc.local` to override configs from `~/.zshrc`.

## What it does

TBC
