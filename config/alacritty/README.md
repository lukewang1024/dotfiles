# Alacritty Config Customization

Create `local.toml` in this folder, then add your customization there.

## Light / dark theme (follows macOS)

Alacritty has no native OS-appearance following, so the theme is swapped by a
helper instead of hardcoded:

- `theme-dark.toml` / `theme-light.toml` — the two One palettes (from
  `rakr/vim-one`, matching the editor).
- `theme-active.toml` — gitignored; a copy of whichever variant is active.
  `alacritty.toml` imports **this** file, and Alacritty's `live_config_reload`
  applies changes to it instantly.
- `alacritty-appearance light|dark|auto` (in `~/.local/bin`) writes
  `theme-active.toml`. On every macOS light/dark switch,
  `config/tmux/appearance-{light,dark}.conf` call it — riding the same
  `dark-notify` signal that drives tmux + nvim, so all three stay in sync.

The push signal fires while a tmux server is running (dark-notify lives inside
the login-scoped appearance-daemon). Outside that, run `alacritty-appearance auto` by hand. Font
family etc. still belong in `local.toml`.

## Font

Font family names might be different on different OS, so it is a good candidate for `local.toml`.

- macOS

```toml
[font.normal]
family = "MesloLGS Nerd Font"
```

- Windows / Linux

```toml
[font.normal]
family = "MesloLGS NF"
```
