# Dotfiles and Bootstrap Scripts

## Linux / macOS

### Usage

```bash
$ cd ~
$ git clone https://github.com/lukewang1024/dotfiles .dotfiles # it has to be `.dotfiles`
$ ~/.dotfiles/init macos # bootstrap macOS core environment
```

- Create a file in `$XDG_CONFIG_HOME/.rc.local` to override configs from `~/.dotfiles/config/sh/rc.sh`.
- Create a file in `$XDG_CONFIG_HOME/.zshrc.local` to override configs from `$XDG_CONFIG_HOME/zsh/.zshrc`.

### Keeping already-provisioned machines in sync

Config *content* is symlinked into the repo, so editing a file and pushing means
every machine picks it up on the next `git pull` — no extra step. Only *new setup
steps* (new symlinks, tmux/vim plugins, wrappers, XDG dirs) need re-running:

```bash
$ cd ~/.dotfiles && git pull   # post-merge hook auto-runs `./init sync` when
                               # provisioning files (bootstrap/, util/, plugin
                               # manifests) changed; a no-op otherwise
$ ~/.dotfiles/init sync        # or run the reconcile by hand anytime
```

`./init sync` re-runs only the fast, idempotent link/plugin steps — it never
prompts, sudos, or reinstalls toolchains/packages, so it's safe on every pull.
The hook is wired per-machine via `core.hooksPath` on first `./init sync` (or any
full `cli`/`all` provision); because the hook script itself is tracked under
`util/git/hooks/`, it then stays current through git.

### MacOS

TODO

### Linux

#### Keyboard modifications

##### vim-style navigation with `xmodmap`

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

##### More escapes with `xcape`

Drop the below line to `.xinitrc`, after `xmodmap ~/.Xmodmap` line to have short press of `Caps_Lock` and `Control_L` to dispatch `Esc` key instead.

```
xcape -e 'Control_L=Escape;Mode_switch=Escape'
```

#### i3 setup

##### Launch arbitrary website with keyboard shortcut

- Create shortcut for the website:
  - Click `...` -> `More tools` -> `Create shortcut...`.
  - Check `Open as window` and create.
  - The shortcut is created at `~/Desktop` by default.
- Open the web app window and find its instance identifier with `xprop`:
  - e.g. `crx_cblkndcnkihlfpikpeedddgaecggkbcm`
- Add the instance identifier to `~/.Xresources.d/custom` as a variable.
- Read the variable in i3 config and use it to identify the exact app window.
- Current list of configured web apps:
  - `web_app.lark`
  - ...

## Windows

### Usage

```
cd "$env:USERPROFILE"
Invoke-WebRequest -Uri https://raw.githubusercontent.com/lukewang1024/dotfiles/master/init.ps1 -OutFile "$env:USERPROFILE\init.ps1"
.\init.ps1 core
```
