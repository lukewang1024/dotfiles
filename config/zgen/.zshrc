source ~/.zgen/zgen.zsh

if ! zgen saved; then
  echo 'Creating a zgen save'

  source ~/.dotfiles/config/shared/rc.sh
  export SHELL=zsh

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


    # completions
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-completions src
    esc/conda-zsh-completion

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
    elif [ -f /etc/debian_version ]; then
      zgen oh-my-zsh plugins/ubuntu
    elif [ -f /etc/fedora-release ]; then
      zgen oh-my-zsh plugins/fedora
    fi
  fi

  # These plugin needs to be loaded last and the order matters
  zgen load zsh-users/zsh-syntax-highlighting
  zgen load zsh-users/zsh-history-substring-search

  # Plugin customizations
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
  ZSH_AUTOSUGGEST_USE_ASYNC=1
  PURE_PROMPT_SYMBOL=λ
  PURE_GIT_DOWN_ARROW=▼
  PURE_GIT_UP_ARROW=▲

  [ -f ~/.zshrc.local ] && source ~/.zshrc.local

  zgen save
fi
