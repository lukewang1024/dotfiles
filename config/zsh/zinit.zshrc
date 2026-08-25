dotfiles_dir="${DOTFILES_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}"
[ -d "$dotfiles_dir" ] || dotfiles_dir="$HOME/.dotfiles"
config_dir="$dotfiles_dir/config"

GIT_AUTO_FETCH_INTERVAL=1200 # 20min

source "$config_dir/utils.sh";
source "$config_dir/zsh/xdg-ninja-patch.zsh"
# Keep lightweight shell preparation before the heavier shared rc.
source "$config_dir/zsh/prepare.zsh"
source "$config_dir/sh/rc.sh"

# - - - - - - - - - - - - - - - - - - - -
# Zinit Configuration
# - - - - - - - - - - - - - - - - - - - -

source "$XDG_DATA_HOME/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-rust

# History state must be established before the first prompt/command. Loading
# this in the Turbo `wait` batch below can miss early commands and directory
# changes before its fc stack and hooks exist.
zinit snippet OMZP::per-directory-history/per-directory-history.zsh/
source "$config_dir/zsh/per-directory-history-fix.zsh"

# - - - - - - - - - - - - - - - - - - - -
# Plugins
# - - - - - - - - - - - - - - - - - - - -

# Most OMZ plugins are single self-contained files — load them as OMZP:: snippets
# (fast, individually fetched & cached, all Turbo-deferred). Multi-file OMZ
# plugins that source sibling files can't be loaded this way and are handled by
# the multisrc block further below.
zinit wait lucid for \
  OMZL::directories.zsh \
  OMZL::git.zsh \
  OMZL::key-bindings.zsh \
  OMZL::theme-and-appearance.zsh \
  OMZP::colored-man-pages/colored-man-pages.plugin.zsh \
  OMZP::command-not-found/command-not-found.plugin.zsh \
  OMZP::common-aliases/common-aliases.plugin.zsh \
  OMZP::copybuffer/copybuffer.plugin.zsh \
  OMZP::copyfile/copyfile.plugin.zsh \
  OMZP::copypath/copypath.plugin.zsh \
  OMZP::cp/cp.plugin.zsh \
  OMZP::dircycle/dircycle.plugin.zsh \
  OMZP::encode64/encode64.plugin.zsh \
  OMZP::extract/extract.plugin.zsh \
  OMZP::fancy-ctrl-z/fancy-ctrl-z.plugin.zsh \
  OMZP::fzf/fzf.plugin.zsh \
  OMZP::git/git.plugin.zsh \
  OMZP::git-auto-fetch/git-auto-fetch.plugin.zsh \
  OMZP::git-extras/git-extras.plugin.zsh \
  OMZP::git-flow-avh/git-flow-avh.plugin.zsh \
  OMZP::gitignore/gitignore.plugin.zsh \
  OMZP::globalias/globalias.plugin.zsh \
  OMZP::golang/golang.plugin.zsh \
  OMZP::history/history.plugin.zsh \
  as'completion' OMZP::httpie/_httpie \
  OMZP::npm/npm.plugin.zsh \
  OMZP::rsync/rsync.plugin.zsh \
  OMZP::sudo/sudo.plugin.zsh \
  OMZP::systemadmin/systemadmin.plugin.zsh \
  OMZP::taskwarrior/taskwarrior.plugin.zsh \
  OMZP::tig/tig.plugin.zsh \
  OMZP::urltools/urltools.plugin.zsh \
  OMZP::vscode/vscode.plugin.zsh \
  OMZP::web-search/web-search.plugin.zsh \
  OMZP::yarn/yarn.plugin.zsh \
  supercrabtree/k \
  ver'main' conda-incubator/conda-zsh-completion \
  zsh-users/zsh-history-substring-search \
  lukewang1024/zsh-tmuxinator \
  atload'_zsh_autosuggest_start' zsh-users/zsh-autosuggestions \
  atpull'zinit creinstall -q .' blockf zsh-users/zsh-completions

# Multi-file OMZ plugins: a plain OMZP:: snippet only copies the .plugin.zsh and
# leaves siblings behind, so these break at runtime (gitfast -> git-prompt.sh,
# macos -> music/spotify, emoji -> emoji-char-definitions.zsh, tmux ->
# tmux.extra.conf/tmux.only.conf, which a bare `tmux` passes to `tmux -f` and
# tmux then dies with "No such file or directory"). The old `svn`
# whole-dir fetch is dead (GitHub dropped Subversion on 2024-01-08). Instead load
# Oh My Zsh as ONE Turbo plugin and `multisrc` these files in place (siblings
# intact). One clone, Turbo-deferred, updated via `zinit update ohmyzsh`.
# pick'/dev/null' is essential: without it zinit auto-sources the repo's main
# file (oh-my-zsh.sh), which boots the whole OMZ framework (defines `omz`, sets
# ZSH_CACHE_DIR, runs its own compinit/termsupport). We only want the 3 files.
() {
  local -a omz=(
    plugins/gitfast/gitfast.plugin.zsh
    plugins/emoji/emoji.plugin.zsh
    plugins/tmux/tmux.plugin.zsh
  )
  is_macos && omz+=( plugins/macos/macos.plugin.zsh )
  zinit ice wait lucid pick'/dev/null' multisrc"${(j: :)omz}"
  zinit light ohmyzsh/ohmyzsh
}

zinit wait'1' lucid for \
  atinit'zicompinit; zicdreplay' zdharma-continuum/fast-syntax-highlighting

# OS specific plugins

if is_cygwin; then
  zinit ice wait lucid; zinit snippet OMZP::cygwin/cygwin.plugin.zsh
else # *nix
  zinit wait lucid for \
    OMZP::colorize/colorize.plugin.zsh \
    as'completion' OMZP::docker/completions/_docker \
    OMZP::vagrant/vagrant.plugin.zsh

  if is_macos; then
    zinit wait lucid for \
      OMZP::brew/brew.plugin.zsh \
      OMZP::forklift/forklift.plugin.zsh

  elif is_linux; then
    if [ -f /etc/arch-release ]; then
      zinit wait lucid for \
        OMZP::archlinux/archlinux.plugin.zsh \
        /usr/share/doc/pkgfile/command-not-found.zsh

    elif [ -f /etc/debian_version ]; then
      if exists lsb_release && [[ $(lsb_release -i | cut -c17-) == 'Ubuntu' ]]; then
        zinit wait lucid for \
          OMZP::ubuntu/ubuntu.plugin.zsh

      fi
    elif [ -f /etc/fedora-release ]; then
      zinit wait lucid for \
        OMZP::dnf/dnf.plugin.zsh

    fi
  fi
fi

# Local, hand-edited config: `source` directly rather than via `zinit snippet`.
# zinit caches AND zcompiles a snippet on first load and never re-reads a local
# file afterward, so edits here silently keep running the stale cached copy until
# the cache is busted (this bit us: a finish.zsh rewrite never took effect). These
# load synchronously (no Turbo) so zinit buys nothing — plain `source` always
# reads the live file. Matches the `source` calls at the top of this file.
source "$config_dir/zsh/rc.zsh"

[ -f "$XDG_CONFIG_HOME/.zshrc.local" ] && source "$XDG_CONFIG_HOME/.zshrc.local"

source "$config_dir/zsh/finish.zsh"

# pnpm
export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
