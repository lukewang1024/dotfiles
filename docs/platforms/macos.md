# macOS setup

The macOS bootstrap combines Homebrew package installation, tracked application
configuration, macOS defaults, and user-level helper commands.

## Design

`bootstrap/macos.sh` owns the package and application selections. It reuses the
shared Unix setup from `bootstrap/env.sh` and `bootstrap/nix.sh`, then applies
macOS-specific configuration such as Hammerspoon, Karabiner, Rime, terminal
settings, and system defaults.

The modes are cumulative selections, not increasing safety levels:

| Mode | Includes |
| --- | --- |
| `core` | Core CLI tools and core GUI applications |
| `cli` | Core CLI plus the extended CLI list |
| `gui` | Core GUI plus the extended GUI/Mac App Store list |
| `all` | Extended CLI and extended GUI flows |
| `game` | Gaming-specific setup |

Review the corresponding function and package arrays in `bootstrap/macos.sh`
before using an extended mode.

## Install a new machine

Prerequisites are a macOS account that can authorize system changes, network
access, and the Command Line Tools required by Git/Homebrew.

```sh
git clone https://github.com/lukewang1024/dotfiles "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" macos core
```

The script installs Homebrew when missing, installs the selected package set,
creates XDG directories, links tracked configuration, and applies the relevant
macOS defaults. Some steps may prompt for authorization or application access.

Restart the shell after the first run so its startup files and environment take
effect.

## Update and reconcile

```sh
cd "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
git pull
./init sync
```

The explicit `sync` is usually redundant after `git pull`, because the tracked
post-merge hook runs it when provisioning files changed. Running it again is
safe and useful when checking a newly added link.

## Apply one group of defaults

The maintenance entrypoint can source a module and run one function:

```sh
"${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/init" run macos-defaults better_macos_defaults
```

Inspect the function first: defaults commands mutate the current user or system
preferences and may require affected applications to restart.

## Verify

Check the parts relevant to the chosen mode:

```sh
brew --version
git -C "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles" status --short
test -L ~/.config/zsh/.zshrc
test -x ~/.local/bin/theme-sync
git -C "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles" config --get core.hooksPath
```

Also confirm GUI configuration where applicable:

- Hammerspoon and Karabiner can read their linked configuration;
- Rime has loaded the tracked schema from `~/Library/Rime`;
- terminal and appearance settings survive an application restart;
- `./init sync` completes without requiring `sudo`.

## Recover an overwritten destination

Before replacing a managed destination, the shared linker normally moves it to
the same path with a `~` suffix. Inspect both paths before restoring anything:

```sh
ls -ld ~/.config/zsh/.zshrc ~/.config/zsh/.zshrc~
```

Remove the managed symlink and move the backup into place only when you have
confirmed the exact target.

