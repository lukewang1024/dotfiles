# Linux setup

Linux support separates distro package selection from shared desktop and shell
configuration. Debian-family packages live in `bootstrap/debian.sh`, Arch
packages live in `bootstrap/arch.sh`, and shared application links live in
`bootstrap/linux.sh`.

## Design

Both distro flows build on the common environment in `bootstrap/env.sh` and the
cross-Unix package/configuration helpers in `bootstrap/nix.sh`.

| Mode | Includes |
| --- | --- |
| `core` | Core CLI tools and core GUI environment |
| `cli` | Core CLI plus extended command-line tools |
| `gui` | Core GUI plus the extended desktop stack |
| `all` | Extended CLI and GUI flows |
| `game` | Arch-specific gaming setup |

The GUI path is opinionated around X11 tooling such as i3, X resources,
Polybar, Rofi, and systemd user units. Do not run it on an unrelated desktop
without reviewing `bootstrap/linux.sh`.

## Install a new machine

Debian or Ubuntu family:

```sh
git clone https://github.com/lukewang1024/dotfiles "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" core
```

Arch family:

```sh
git clone https://github.com/lukewang1024/dotfiles "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" core
```

The distro bootstrap uses the native package manager and may invoke `sudo`.
The Arch entrypoint also configures pacman mirrors before selecting a mode.
Review package arrays and distro assumptions before the first run.

## Update and reconcile

```sh
cd "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
git pull
./init sync
```

`sync` refreshes the shared shell/editor/tool links but does not repeat the
full distro package or graphical-desktop setup.

## Vim-style navigation layer

The tracked `.Xmodmap` turns Caps Lock into `Mode_switch` and provides this
navigation layer:

| Input | Result |
| --- | --- |
| `Shift + Caps Lock` | Caps Lock |
| `Caps Lock + 4` / `0` | Line end / start |
| `Caps Lock + h/j/k/l` | Cursor left/down/up/right |
| `Caps Lock + x` | Delete |
| `Caps Lock + s/d/f/g` | Pointer left/down/up/right |
| `Caps Lock + v/b/n` | Mouse buttons 1/2/3 |

Pointer controls depend on desktop accessibility support. To emit Escape from
a short Caps Lock or Control press, add this after `xmodmap ~/.Xmodmap` in
`.xinitrc`:

```sh
xcape -e 'Control_L=Escape;Mode_switch=Escape'
```

## Configure an i3 web-app shortcut

1. Create a browser shortcut with **Open as window** enabled.
2. Open it and use `xprop` to find its instance identifier.
3. Add the identifier as a variable in `~/.Xresources.d/custom`.
4. Reference that variable from the tracked i3 configuration.
5. Reload X resources and i3, then verify the matching rule.

`~/.Xresources.d/custom` is the machine-local place for identifiers that should
not be committed.

## Verify

```sh
git -C "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles" status --short
test -L ~/.config/zsh/.zshrc
test -L ~/.config/tmux
test -x ~/.local/bin/theme-sync
git -C "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles" config --get core.hooksPath
```

For a GUI setup, also verify that user units appear under
`~/.config/systemd/user`, X resources load, and the selected desktop session is
available. Run `systemctl --user daemon-reload` when testing newly added units.

Existing managed destinations are normally preserved with a `~` suffix. Inspect
that backup before removing or restoring a link.
