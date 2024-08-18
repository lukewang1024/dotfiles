config_dir="$HOME/.dotfiles/config"

source "$config_dir/utils.sh";
source "$config_dir/sh/rc.sh"
source "$config_dir/zsh/xdg-ninja-patch.zsh"
source "$config_dir/zsh/prepare.zsh"

source $XDG_DATA_HOME/zgen/zgen.zsh

if ! zgen saved; then
  echo 'Creating a zgen save'

  zgen oh-my-zsh

  zgen loadall <<EOPLUGINS
    # plugins
    robbyrussell/oh-my-zsh plugins/colored-man-pages
    robbyrussell/oh-my-zsh plugins/command-not-found
    robbyrussell/oh-my-zsh plugins/common-aliases
    robbyrussell/oh-my-zsh plugins/copybuffer
    robbyrussell/oh-my-zsh plugins/copyfile
    robbyrussell/oh-my-zsh plugins/copypath
    robbyrussell/oh-my-zsh plugins/cp
    robbyrussell/oh-my-zsh plugins/dircycle
    robbyrussell/oh-my-zsh plugins/emoji
    robbyrussell/oh-my-zsh plugins/encode64
    robbyrussell/oh-my-zsh plugins/extract
    robbyrussell/oh-my-zsh plugins/fancy-ctrl-z
    robbyrussell/oh-my-zsh plugins/fzf
    robbyrussell/oh-my-zsh plugins/git
    robbyrussell/oh-my-zsh plugins/git-extras
    robbyrussell/oh-my-zsh plugins/git-flow
    robbyrussell/oh-my-zsh plugins/git-flow-avh
    robbyrussell/oh-my-zsh plugins/gitfast
    robbyrussell/oh-my-zsh plugins/gitignore
    robbyrussell/oh-my-zsh plugins/globalias
    robbyrussell/oh-my-zsh plugins/golang
    robbyrussell/oh-my-zsh plugins/history
    robbyrussell/oh-my-zsh plugins/httpie
    robbyrussell/oh-my-zsh plugins/npm
    robbyrussell/oh-my-zsh plugins/per-directory-history
    robbyrussell/oh-my-zsh plugins/rsync
    robbyrussell/oh-my-zsh plugins/sudo
    robbyrussell/oh-my-zsh plugins/systemadmin
    robbyrussell/oh-my-zsh plugins/taskwarrior
    robbyrussell/oh-my-zsh plugins/tig
    robbyrussell/oh-my-zsh plugins/tmux
    robbyrussell/oh-my-zsh plugins/urltools
    robbyrussell/oh-my-zsh plugins/vscode
    robbyrussell/oh-my-zsh plugins/web-search
    robbyrussell/oh-my-zsh plugins/yarn

    supercrabtree/k

    # completions
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-completions src
    conda-incubator/conda-zsh-completion . main
    lukewang1024/zsh-tmuxinator
EOPLUGINS
  # ^ can't indent this EOPLUGINS

  # theme
  zgen load romkatv/powerlevel10k powerlevel10k

  # OS specific plugins

  if is_cygwin; then
    zgen oh-my-zsh plugins/cygwin
  else # *nix
    zgen oh-my-zsh plugins/colorize
    zgen oh-my-zsh plugins/docker
    zgen oh-my-zsh plugins/vagrant
  fi

  if is_macos; then
    zgen oh-my-zsh plugins/macos
    zgen oh-my-zsh plugins/brew
    zgen oh-my-zsh plugins/forklift
  fi

  if is_linux; then
    if [ -f /etc/arch-release ]; then
      zgen oh-my-zsh plugins/archlinux
      zgen load /usr/share/doc/pkgfile/command-not-found.zsh
    elif [ -f /etc/debian_version ]; then
      if exists lsb_release && [[ $(lsb_release -i | cut -c17-) == 'Ubuntu' ]]; then
        zgen oh-my-zsh plugins/ubuntu
      fi
    elif [ -f /etc/fedora-release ]; then
      zgen oh-my-zsh plugins/dnf
    fi
  fi

  # These plugin needs to be loaded last and THE ORDER MATTERS
  zgen load zdharma-continuum/fast-syntax-highlighting
  zgen load zsh-users/zsh-history-substring-search
  zgen load "$config_dir/zsh/rc.zsh"

  [ -f "$XDG_CONFIG_HOME/.zshrc.local" ] && zgen load "$XDG_CONFIG_HOME/.zshrc.local"

  zgen save
fi

source "$config_dir/zsh/finish.zsh"
