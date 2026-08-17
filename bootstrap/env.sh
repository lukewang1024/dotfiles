source "$partial_dir/shell.sh"
source "$partial_dir/pkg.sh"
source "$config_dir/sh/xdg-ninja-patch.sh"

git_setup()
{
  blank_lines
  echo 'Applying global git configs...'

  mkdir -p "$XDG_CONFIG_HOME/git"

  # Back up the current config file
  if [ -f "$XDG_CONFIG_HOME/git/config" ]; then
    printf 'Backing up current $XDG_CONFIG_HOME/git/config... '
    local git_user_identities="$(git config --global --list | grep -E '^user\.\w+\.\w+=.+$')"
    mv "$XDG_CONFIG_HOME/git/config" "$XDG_CONFIG_HOME/git/config~"
    echo 'Done.'
  fi

  echo 'Applying new git configs...'
  cat "$config_dir/git/alias" > "$XDG_CONFIG_HOME/git/config"
  cat "$config_dir/git/common" >> "$XDG_CONFIG_HOME/git/config"
  [ -f "$config_dir/git/local" ] && cat "$config_dir/git/local" >> "$XDG_CONFIG_HOME/git/config"

  backup_then_symlink "$util_dir/shell/git-branch-cleanup" "$bin_dir/git-branch-cleanup"
  backup_then_symlink "$util_dir/shell/git-clone-bare" "$bin_dir/git-clone-bare"
  backup_then_symlink "$util_dir/shell/git-new-branch" "$bin_dir/git-new-branch"
  backup_then_symlink "$util_dir/shell/git-set-identity" "$bin_dir/git-set-identity"

  # MacOS
  if is_macos; then
    git config --global credential.helper osxkeychain
  fi

  # WSL & Cygwin
  uname -r | grep Microsoft &> /dev/null # returns 0 on WSL
  if [[ $? == 0 ]] || is_cygwin; then
    git config --global core.autocrlf input
    git config --global core.fileMode false
  fi

  # Git user identities
  if [ -n "$git_user_identities" ]; then
    echo 'Git user identities were configured as below previously.'
    echo "$git_user_identities"
    read -p 'Do you want to re-apply them? [Y/n]' -n 1 -r; echo
    if [ -z $REPLY ] || [ $REPLY = 'y' ] || [ $REPLY = 'Y' ]; then
      sedCmd=$(is_macos && echo gsed || echo sed)
      eval "$(echo "$git_user_identities" | $sedCmd -E 's/^(user\.\w+\.\w+)=(.+)$/git config --global \1 "\2"/g')"
      echo 'Previous identities re-applied.'
    fi
  fi

  while : ; do
    read -p 'Add a new identity (Leave blank to skip):' -r git_user_identity; echo
    if [ -z "$git_user_identity" ]; then echo 'Skipped.'; break; fi

    while : ; do
      read -p 'Name:' git_user_name
      [ -n "$git_user_name" ] && break
      echo 'Name cannot be empty!'
    done

    while : ; do
      read -p 'Email:' git_user_email
      [ -n "$git_user_email" ] && break
      echo 'Email cannot be empty!'
    done

    read -p 'SigningKey:' git_user_signingKey

    git config --global "user.$git_user_identity.name" "$git_user_name"
    git config --global "user.$git_user_identity.email" "$git_user_email"
    if [ -n "$git_user_signingKey" ]; then
      git config --global "user.$git_user_identity.signingKey" "$git_user_signingKey"
    fi
  done

  unset git_user_identity
  unset git_user_name
  unset git_user_email
  unset git_user_signingKey

  echo 'Done.'
}

anyenv_setup()
{
  anyenv install --force-init https://github.com/lukewang1024/anyenv-install.git
  anyenv install --skip-existing goenv
  anyenv install --skip-existing nodenv
  anyenv install --skip-existing pyenv
  anyenv install --skip-existing rbenv
  eval "$(anyenv init -)"

  local GH='https://github.com'

  local NODENV_PLUGINS="$(nodenv root)/plugins"
  sync_config_repo "$NODENV_PLUGINS/node-build"                 "$GH/nodenv/node-build"
  sync_config_repo "$NODENV_PLUGINS/nodenv-default-packages"    "$GH/nodenv/nodenv-default-packages"
  sync_config_repo "$NODENV_PLUGINS/nodenv-package-json-engine" "$GH/nodenv/nodenv-package-json-engine"
  sync_config_repo "$NODENV_PLUGINS/nodenv-package-rehash"      "$GH/nodenv/nodenv-package-rehash"
  sync_config_repo "$NODENV_PLUGINS/nodenv-update"              "$GH/nodenv/nodenv-update"

  local PYENV_PLUGINS="$(pyenv root)/plugins"
  sync_config_repo "$PYENV_PLUGINS/pyenv-doctor"     "$GH/pyenv/pyenv-doctor"
  sync_config_repo "$PYENV_PLUGINS/pyenv-update"     "$GH/pyenv/pyenv-update"
  sync_config_repo "$PYENV_PLUGINS/pyenv-virtualenv" "$GH/pyenv/pyenv-virtualenv"
  sync_config_repo "$PYENV_PLUGINS/pyenv-which-ext"  "$GH/pyenv/pyenv-which-ext"

  local RBENV_PLUGINS="$(rbenv root)/plugins"
  sync_config_repo "$RBENV_PLUGINS/ruby-build"          "$GH/rbenv/ruby-build"
  sync_config_repo "$RBENV_PLUGINS/rbenv-vars"          "$GH/rbenv/rbenv-vars"
  sync_config_repo "$RBENV_PLUGINS/rbenv-each"          "$GH/rbenv/rbenv-each"
  sync_config_repo "$RBENV_PLUGINS/rbenv-default-gems"  "$GH/rbenv/rbenv-default-gems"
  sync_config_repo "$RBENV_PLUGINS/rbenv-update"        "$GH/rkh/rbenv-update"
  sync_config_repo "$RBENV_PLUGINS/rbenv-communal-gems" "$GH/tpope/rbenv-communal-gems"
  sync_config_repo "$RBENV_PLUGINS/rbenv-user-gems"     "$GH/mislav/rbenv-user-gems"
}

rustup_setup()
{
  blank_lines
  echo 'Installing rustup...'
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  echo 'Done.'
}

python_setup()
{
  blank_lines
  printf 'Symlinking pythonrc... '
  backup_then_symlink "$config_dir/python" "$XDG_CONFIG_HOME/python"
  touch "$XDG_STATE_HOME/python_history"
  echo 'Done.'
}

pnpm_setup()
{
  blank_lines
  printf 'Symlinking pnpm config... '
  backup_then_symlink "$config_dir/pnpm" "$XDG_CONFIG_HOME/pnpm"
  echo 'Done.'
}

npm_setup()
{
  blank_lines
  local npmrc="$XDG_CONFIG_HOME/npm/npmrc"

  # Back up the current config file
  if [ -f "$npmrc" ]; then
    printf "Backing up current ${npmrc}... "
    mv "$npmrc" "$npmrc~"
    echo 'Done.'
  fi

  echo 'Applying new npmrc...'
  cat "$config_dir/npm/common" > "$npmrc"
  [ -f "$config_dir/npm/local" ] && cat "$config_dir/npm/local" >> "$npmrc"
  echo 'Done.'
}

util_setup()
{
  blank_lines
  printf 'Installing handy configs and wrappers... '
  backup_then_symlink "$config_dir/proxychains/proxychains.conf" "$XDG_CONFIG_HOME/proxychains.conf"
  # Shared, tool-agnostic agent conventions (SSOT): AGENTS.md → codex/opencode
  # global paths; CLAUDE.md imports it (Claude reads CLAUDE.md, not AGENTS.md).
  backup_then_symlink "$config_dir/agent/AGENTS.md" "$HOME/.codex/AGENTS.md"
  backup_then_symlink "$config_dir/agent/AGENTS.md" "$XDG_CONFIG_HOME/opencode/AGENTS.md"
  backup_then_symlink "$config_dir/agent/AGENTS.md" "$HOME/.claude/AGENTS.md"
  backup_then_symlink "$config_dir/agent/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  backup_then_symlink "$util_dir/agent/agent-sidebar-hooks-install" "$bin_dir/agent-sidebar-hooks-install"
  backup_then_symlink "$util_dir/agent/agent-sidebar-binary-install" "$bin_dir/agent-sidebar-binary-install"
  backup_then_symlink "$util_dir/agent/claude-settings-apply" "$bin_dir/claude-settings-apply"
  backup_then_symlink "$util_dir/agent/claude-statusline" "$bin_dir/claude-statusline"
  backup_then_symlink "$util_dir/agent/codex-settings-apply" "$bin_dir/codex-settings-apply"
  backup_then_symlink "$util_dir/agent/agent-skills-install" "$bin_dir/agent-skills-install"
  backup_then_symlink "$util_dir/agent/agent-skills-prune" "$bin_dir/agent-skills-prune"
  backup_then_symlink "$util_dir/agent/home-dotdir-prune" "$bin_dir/home-dotdir-prune"
  backup_then_symlink "$util_dir/agent/agent-hooks-prune" "$bin_dir/agent-hooks-prune"
  backup_then_symlink "$util_dir/agent/mcp-sync" "$bin_dir/mcp-sync"
  # Alacritty light/dark theme swap — driven on macOS appearance changes by
  # config/tmux/appearance-{light,dark}.conf; `auto` seeds theme-active.toml.
  backup_then_symlink "$util_dir/shell/alacritty-appearance" "$bin_dir/alacritty-appearance"
  # Login-scoped light/dark watcher (macOS): keeps nvim + Alacritty on the OS
  # appearance even with no tmux running. Install per-machine (non-interactive):
  #   appearance-daemon install
  backup_then_symlink "$util_dir/shell/appearance-daemon" "$bin_dir/appearance-daemon"
  # Manual reconcile hammer (OSC 11) + its argument mode, which is also the entry
  # point a pushed light/dark value is applied through on an SSH devbox; the
  # local pusher that relays to every attached devbox; and the OS-appearance
  # tmux fallback. Reconciled here (not only in a full provision) so `./init sync`
  # sets up the whole light/dark relay on a plain pull.
  backup_then_symlink "$util_dir/shell/theme-sync" "$bin_dir/theme-sync"
  backup_then_symlink "$util_dir/shell/theme-push-remotes" "$bin_dir/theme-push-remotes"
  backup_then_symlink "$util_dir/shell/tmux-appearance-fallback" "$bin_dir/tmux-appearance-fallback"
  # Pull, build, install, sign, and restart tmux-agent-sidebar without requiring
  # an agent-driven update session.
  backup_then_symlink "$util_dir/shell/tmux-agent-sidebar-update" "$bin_dir/tmux-agent-sidebar-update"
  # Layout presets that keep the agent sidebar out of the layout computation —
  # bound to prefix + M-1..M-7 / Space / e by config/tmux/tmux.conf, so the keys
  # are dead without this link.
  backup_then_symlink "$util_dir/shell/tmux-layout-keep-sidebar" "$bin_dir/tmux-layout-keep-sidebar"
  backup_then_symlink "$util_dir/shell/tmux-sidebar-resurrect" "$bin_dir/tmux-sidebar-resurrect-save"
  backup_then_symlink "$util_dir/shell/tmux-sidebar-resurrect" "$bin_dir/tmux-sidebar-resurrect-restore"
  backup_then_symlink "$util_dir/shell/tmux-sidebar-resurrect" "$bin_dir/tmux-sidebar-resurrect-pane"
  backup_then_symlink "$util_dir/spark/pyspark-jupyter" "$bin_dir/pyspark-jupyter"
  backup_then_symlink "$util_dir/spark/pyspark-jupyter-public" "$bin_dir/pyspark-jupyter-public"
  # Kerberos ticket auto-renew (macOS keychain / Linux keytab). Install per-machine
  # with: kinit-auto-login install  (not run here — it prompts for the SSO password).
  backup_then_symlink "$util_dir/kerberos/kinit-auto-login" "$bin_dir/kinit-auto-login"
  backup_then_symlink "$util_dir/dotfiles/migrate-xdg" "$bin_dir/dotfiles-migrate-xdg"
  # Apply shared Claude Code settings base, fetch the tmux-agent-sidebar binary
  # via its non-interactive downloader (so prefix+Tab binds without the manual
  # install menu), and wire its Claude Code hooks. All idempotent and best-effort
  # (|| true so a failure never aborts the bootstrap); their output is left
  # visible on purpose -- on a fresh machine the binary download is a multi-second
  # network step, and swallowing it into /dev/null just looks like an unexplained
  # hang (each also prints a clear "skipping" notice when a dep is missing).
  "$util_dir/agent/claude-settings-apply" || true
  "$util_dir/agent/codex-settings-apply" || true
  "$util_dir/agent/agent-skills-install" || true
  "$util_dir/agent/agent-skills-prune" --apply || true
  "$util_dir/agent/agent-sidebar-binary-install" || true
  "$util_dir/agent/agent-sidebar-hooks-install" || true
  "$util_dir/agent/agent-hooks-prune" --apply || true
  # Seed Alacritty's theme-active.toml (gitignored) from the current macOS
  # appearance so a fresh checkout has a theme before the first light/dark switch.
  is_macos && "$util_dir/shell/alacritty-appearance" auto >/dev/null 2>&1 || true
  # Wire the dotfiles repo's own git hooks so a plain `git pull` auto-reconciles
  # this machine (post-merge -> ./init sync). See git_hooks_setup below.
  git_hooks_setup
  echo 'Done.'
}

# Point the dotfiles repo's local core.hooksPath at the tracked hooks dir. Because
# the hook scripts live under version control (util/git/hooks), they propagate to
# every machine through git itself — only this one-line local config (per-machine,
# not shared) has to be set, which util_setup does on both full provisioning and
# `./init sync`. Idempotent: `git config` just overwrites the same value.
git_hooks_setup()
{
  local hooks_dir="$util_dir/git/hooks"
  [ -d "$hooks_dir" ] || return 0
  printf 'Wiring dotfiles git hooks (post-merge auto-sync)... '
  chmod +x "$hooks_dir/"* 2> /dev/null
  git -C "$repo_path" config --local core.hooksPath "$hooks_dir"
  echo 'Done.'
}

# Reconcile an ALREADY-PROVISIONED machine with newly-added setup steps after a
# `git pull`. Runs only the fast, idempotent, non-interactive link/plugin steps:
# NO interactive prompts (git identities), NO sudo (chsh / global zshenv), and NO
# slow toolchain/package installs (anyenv, rustup, brew/apt). Safe to run on every
# pull — the repo's post-merge hook calls it for you when provisioning files
# change. A brand-new machine still runs the full `./init macos` first.
sync_setup()
{
  ssh_setup
  tmux_setup
  tig_setup
  vim_setup
  npm_setup
  pnpm_setup
  python_setup

  # Re-link the zsh rc files only. The one-time global-zshenv (sudo) and chsh
  # steps belong to full provisioning, not to a per-pull reconcile, so they are
  # deliberately left out here.
  blank_lines
  printf 'Re-linking zsh rc files... '
  backup_then_symlink "$config_dir/zsh/zinit.zshrc" "$XDG_CONFIG_HOME/zsh/.zshrc"
  backup_then_symlink "$config_dir/zsh/.zlogin" "$XDG_CONFIG_HOME/zsh/.zlogin"
  backup_then_symlink "$config_dir/zsh/.zshenv" "$XDG_CONFIG_HOME/zsh/.zshenv"
  backup_then_symlink "$config_dir/zsh/.zprofile" "$XDG_CONFIG_HOME/zsh/.zprofile"
  backup_then_symlink "$config_dir/starship/starship.toml" "$XDG_CONFIG_HOME/starship.toml"
  echo 'Done.'

  util_setup       # idempotent symlinks/wrappers + git-hooks wiring
  xdg_dir_create
}

basic_env_setup()
{
  profile_setup
  shell_setup # zgen by default; set DOTFILES_SHELL=zinit|bash_it to override
  ssh_setup
  tmux_setup
  git_setup
  tig_setup
  anyenv_setup
  rustup_setup
  npm_setup
  pnpm_setup
  python_setup
  vim_setup
  xdg_dir_create
}

xdg_dir_create()
{
  printf 'Creating XDG state & cache directories...'
  # android
  mkdir -p "$XDG_DATA_HOME/android"
  # bash
  mkdir -p "$XDG_STATE_HOME/bash"
  # less
  mkdir -p "$XDG_STATE_HOME/less"
  # npm
  mkdir -p "$XDG_CONFIG_HOME/npm"
  mkdir -p "$XDG_DATA_HOME/npm"
  mkdir -p "$XDG_CACHE_HOME/npm"
  mkdir -p "$XDG_STATE_HOME/npm/logs"
  # ncurses
  mkdir -p "$XDG_DATA_HOME/terminfo"
  # tldr
  mkdir -p "$XDG_CACHE_HOME/tldr"
  # wakatime
  mkdir -p "$XDG_CONFIG_HOME/wakatime"
  # zsh
  mkdir -p "$XDG_CACHE_HOME/zsh"
  mkdir -p "$XDG_STATE_HOME/zsh"
  echo 'Done.'
}

extra_env_setup()
{
  util_setup

  install_common_packages
}

env_setup()
{
  basic_env_setup
  extra_env_setup
}

rime_setup()
{
  ( \
    mkdir -p "$HOME/tmp" && \
    cd "$HOME/tmp" && \
    curl -fsSL https://git.io/rime-install | bash -s -- jyutping emoji \
  )
}
