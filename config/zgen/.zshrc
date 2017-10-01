source ~/.dotfiles/config/shared/rc.sh

export SHELL=zsh

source ~/.zgen/zgen.zsh

if ! zgen saved; then
  echo 'Creating a zgen save'

  zgen oh-my-zsh

  zgen loadall <<EOPLUGINS
    # plugins
    robbyrussell/oh-my-zsh plugins/colored-man-pages
    robbyrussell/oh-my-zsh plugins/command-not-found
    robbyrussell/oh-my-zsh plugins/common-aliases
    robbyrussell/oh-my-zsh plugins/copyfile
    robbyrussell/oh-my-zsh plugins/copydir
    robbyrussell/oh-my-zsh plugins/cp
    robbyrussell/oh-my-zsh plugins/dircycle
    robbyrussell/oh-my-zsh plugins/encode64
    robbyrussell/oh-my-zsh plugins/extract
    robbyrussell/oh-my-zsh plugins/fasd
    robbyrussell/oh-my-zsh plugins/gitfast
    robbyrussell/oh-my-zsh plugins/git-extras
    robbyrussell/oh-my-zsh plugins/git-flow
    robbyrussell/oh-my-zsh plugins/history
    robbyrussell/oh-my-zsh plugins/per-directory-history
    robbyrussell/oh-my-zsh plugins/sudo
    robbyrussell/oh-my-zsh plugins/tmux
    robbyrussell/oh-my-zsh plugins/tmuxinator
    robbyrussell/oh-my-zsh plugins/urltools
    robbyrussell/oh-my-zsh plugins/yarn

    zsh-users/zsh-history-substring-search

    esc/conda-zsh-completion

    # completions
    zsh-users/zsh-completions src

    # theme - pure
    mafredri/zsh-async
    sindresorhus/pure
EOPLUGINS
  # ^ can't indent this EOPLUGINS

  # OS specific plugins

  if [[ $OSTYPE == 'cygwin' ]]; then
    zgen oh-my-zsh plugins/cygwin
  else # *nix
    zgen oh-my-zsh plugins/colorize
    zgen oh-my-zsh plugins/docker
    zgen oh-my-zsh plugins/nvm
    zgen oh-my-zsh plugins/pyenv
    zgen oh-my-zsh plugins/rbenv
    zgen oh-my-zsh plugins/vagrant
  fi

  if [[ $OSTYPE == *'darwin'* ]]; then
    zgen oh-my-zsh plugins/osx
    zgen oh-my-zsh plugins/brew
  fi

  if [[ $OSTYPE == 'linux-gnu' ]]; then
    if [ -f /etc/arch-release ]; then
      zgen oh-my-zsh plugins/archlinux
    elif [ -f /etc/debian-version ]; then
      zgen oh-my-zsh plugins/ubuntu
    fi
  fi

  # This plugin needs to be the last one
  zgen load zsh-users/zsh-syntax-highlighting

  # Plugin customizations
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
  PURE_PROMPT_SYMBOL=λ
  PURE_GIT_DOWN_ARROW=▼
  PURE_GIT_UP_ARROW=▲

  zgen save
fi

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
