config_dir="$HOME/.dotfiles/config"
zsh_config_dir="$config_dir/zsh"

GIT_AUTO_FETCH_INTERVAL=1200 # 20min

source "$config_dir/utils.sh";
source "$config_dir/sh/rc.sh"
source "$zsh_config_dir/prepare.zsh"

# - - - - - - - - - - - - - - - - - - - -
# Zinit Configuration
# - - - - - - - - - - - - - - - - - - - -

source ~/.zinit/bin/zinit.zsh
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# - - - - - - - - - - - - - - - - - - - -
# Theme
# - - - - - - - - - - - - - - - - - - - -

zinit light romkatv/powerlevel10k

# - - - - - - - - - - - - - - - - - - - -
# Annexes
# - - - - - - - - - - - - - - - - - - - -

# Load a few important annexes, without Turbo (this is currently required for annexes)
zinit light-mode compile'handler' for \
  zinit-zsh/z-a-patch-dl \
  zinit-zsh/z-a-as-monitor \
  zinit-zsh/z-a-bin-gem-node \
  zinit-zsh/z-a-submods \
  zdharma/declare-zsh

# - - - - - - - - - - - - - - - - - - - -
# Plugins
# - - - - - - - - - - - - - - - - - - - -

# Not figured out how to get these two plugins to work
  # OMZP::gitfast/gitfast.plugin.zsh \
  # OMZP::emoji/emoji.plugin.zsh \

zinit wait lucid for \
  OMZL::directories.zsh \
  OMZL::git.zsh \
  OMZL::key-bindings.zsh \
  OMZL::theme-and-appearance.zsh \
  OMZP::colored-man-pages/colored-man-pages.plugin.zsh \
  OMZP::command-not-found/command-not-found.plugin.zsh \
  OMZP::common-aliases/common-aliases.plugin.zsh \
  OMZP::copybuffer/copybuffer.plugin.zsh \
  OMZP::copydir/copydir.plugin.zsh \
  OMZP::copyfile/copyfile.plugin.zsh \
  OMZP::cp/cp.plugin.zsh \
  OMZP::dircycle/dircycle.plugin.zsh \
  OMZP::encode64/encode64.plugin.zsh \
  OMZP::extract/extract.plugin.zsh \
  OMZP::fancy-ctrl-z/fancy-ctrl-z.plugin.zsh \
  as'completion' OMZP::fd/_fd \
  OMZP::fzf/fzf.plugin.zsh \
  OMZP::git/git.plugin.zsh \
  OMZP::git-auto-fetch/git-auto-fetch.plugin.zsh \
  OMZP::git-extras/git-extras.plugin.zsh \
  OMZP::git-flow/git-flow.plugin.zsh \
  OMZP::git-flow-avh/git-flow-avh.plugin.zsh \
  OMZP::gitignore/gitignore.plugin.zsh \
  OMZP::globalias/globalias.plugin.zsh \
  OMZP::golang/golang.plugin.zsh \
  OMZP::history/history.plugin.zsh \
  as'completion' OMZP::httpie/_httpie \
  OMZP::npm/npm.plugin.zsh \
  OMZP::per-directory-history/per-directory-history.zsh/ \
  OMZP::rsync/rsync.plugin.zsh \
  OMZP::sudo/sudo.plugin.zsh \
  OMZP::systemadmin/systemadmin.plugin.zsh \
  OMZP::taskwarrior/taskwarrior.plugin.zsh \
  OMZP::tig/tig.plugin.zsh \
  OMZP::tmux/tmux.plugin.zsh \
  OMZP::urltools/urltools.plugin.zsh \
  OMZP::vscode/vscode.plugin.zsh \
  OMZP::web-search/web-search.plugin.zsh \
  OMZP::yarn/yarn.plugin.zsh \
  zsh-users/zsh-history-substring-search \
  lukewang1024/zsh-tmuxinator \
  atload'_zsh_autosuggest_start' zsh-users/zsh-autosuggestions \
  atpull'zinit creinstall -q .' blockf zsh-users/zsh-completions

zinit wait'1' lucid for \
  atinit'zicompinit; zicdreplay' zdharma-continuum/fast-syntax-highlighting

# OS specific plugins

if is_cygwin; then
  zinit ice wait lucid; zinit snippet OMZP::cygwin/cygwin.plugin.zsh
else # *nix
  zinit wait lucid for \
    OMZP::colorize/colorize.plugin.zsh \
    as'completion' OMZP::docker/_docker \
    OMZP::vagrant/vagrant.plugin.zsh \
    OMZP::rbenv/rbenv.plugin.zsh \
    OMZP::pyenv/pyenv.plugin.zsh \
    OMZP::jenv/jenv.plugin.zsh \
    jsahlen/nodenv.plugin.zsh \
    lukewang1024/zsh-goenv

  if is_macos; then
    zinit wait lucid for \
      plugins/macos/macos.plugin.zsh \
      plugins/brew/brew.plugin.zsh \
      plugins/forklift/forklift.plugin.zsh

  elif is_linux; then
    if [ -f /etc/arch-release ]; then
      zinit wait lucid for \
        OMZP::archlinux/archlinux.plugin.zsh \
        /usr/share/doc/pkgfile/command-not-found.zsh

    elif [ -f /etc/debian_version ]; then
      if [[ $(lsb_release -i | cut -c17-) == 'Ubuntu' ]]; then
        zinit wait lucid for \
          OMZP::ubuntu/ubuntu.plugin.zsh

      fi
    elif [ -f /etc/fedora-release ]; then
      zinit wait lucid for \
        OMZP::dnf/dnf.plugin.zsh

    fi
  fi
fi

zinit snippet "$zsh_config_dir/rc.zsh"
zinit snippet "$config_dir/todoist/todoist_functions.sh"

[ -f ~/.zshrc.local ] && zinit snippet ~/.zshrc.local

zinit snippet "$zsh_config_dir/finish.zsh"
