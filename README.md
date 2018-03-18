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

TODO

## MacOS

TODO

## Linux

### Keyboard modifications

#### vim-style navigation with `xmodmap`

Init script will create a symbolic link from `~/.Xmodmap` to `~/.dotfiles/config/x/.Xmodmap`, which provides vim-style cursor / mouse pointer navigation:

From | To
--- | ---
`Caps_Lock` | `Mode_switch`
`Shift + Caps_Lock` | `Caps_Lock`
`Caps_Lock + 4` | line end
`Caps_Lock + 0` | line start
`Caps_Lock + h` | cursor left
`Caps_Lock + j` | cursor down
`Caps_Lock + k` | cursor up
`Caps_Lock + l` | cursor right
`Caps_Lock + x` | delete

Some modifications require accessibility feature to work:

From | To
--- | ---
`Caps_Lock + s` | mouse pointer left
`Caps_Lock + d` | mouse pointer down
`Caps_Lock + f` | mouse pointer up
`Caps_Lock + g` | mouse pointer right
`Caps_Lock + v` | mouse button 1
`Caps_Lock + b` | mouse button 2
`Caps_Lock + n` | mouse button 3

#### More escapes with `xcape`

Drop the below line to `.xinitrc`, after `xmodmap ~/.Xmodmap` line to have short press of `Caps_Lock` and `Control_L` to dispatch `Esc` key instead.

```
xcape -e 'Control_L=Escape;Mode_switch=Escape'
```

## Windows

### WSL

TODO

### Powershell

TODO
