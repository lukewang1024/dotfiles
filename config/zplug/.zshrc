source ~/.dotfiles/config/shared/rc.sh

export SHELL=zsh

source ~/.zplug/init.zsh

# plugins
zplug 'plugins/colored-man-pages', from:oh-my-zsh
zplug 'plugins/command-not-found', from:oh-my-zsh
zplug 'plugins/common-aliases', from:oh-my-zsh
zplug 'plugins/copydir', from:oh-my-zsh
zplug 'plugins/copyfile', from:oh-my-zsh
zplug 'plugins/cp', from:oh-my-zsh
zplug 'plugins/dircycle', from:oh-my-zsh
zplug 'plugins/encode64', from:oh-my-zsh
zplug 'plugins/extract', from:oh-my-zsh
zplug 'plugins/fasd', from:oh-my-zsh
zplug 'plugins/git-extras', from:oh-my-zsh
zplug 'plugins/git-flow', from:oh-my-zsh
zplug 'plugins/gitfast', from:oh-my-zsh
zplug 'plugins/history', from:oh-my-zsh
zplug 'plugins/per-directory-history', from:oh-my-zsh
zplug 'plugins/sudo', from:oh-my-zsh
zplug 'plugins/tmux', from:oh-my-zsh
zplug 'plugins/tmuxinator', from:oh-my-zsh
zplug 'plugins/urltools', from:oh-my-zsh
zplug 'plugins/yarn', from:oh-my-zsh

zplug 'zsh-users/zsh-history-substring-search'
zplug 'zsh-users/zsh-syntax-highlighting', defer:2 # run after compinit
zplug 'esc/conda-zsh-completion'

# completions
zplug 'zsh-users/zsh-completions'

# theme - pure
zplug 'mafredri/zsh-async'
zplug 'sindresorhus/pure', use:pure.zsh, as:theme

# OS specific plugins

if [[ $OSTYPE == 'cygwin' ]]; then
  zplug 'plugins/cygwin', from:oh-my-zsh
else # *nix
  zplug 'plugins/colorize', from:oh-my-zsh
  zplug 'plugins/docker', from:oh-my-zsh
  zplug 'plugins/nvm', from:oh-my-zsh
  zplug 'plugins/pyenv', from:oh-my-zsh
  zplug 'plugins/rbenv', from:oh-my-zsh
  zplug 'plugins/vagrant', from:oh-my-zsh
fi

if [[ $OSTYPE == *'darwin'* ]]; then
  zplug 'plugins/osx', from:oh-my-zsh
  zplug 'plugins/brew', from:oh-my-zsh
fi

if [[ $OSTYPE == 'linux-gnu' ]]; then
  if [ -f /etc/arch-release ]; then
    zplug 'plugins/archlinux', from:oh-my-zsh
  elif [ -f /etc/debian-version ]; then
    zplug 'plugins/ubuntu', from:oh-my-zsh
  fi
fi

# Plugin customizations
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
PURE_PROMPT_SYMBOL=λ
PURE_GIT_DOWN_ARROW=▼
PURE_GIT_UP_ARROW=▲

# Tip: Use `--verbose` upon `check` and `load` to debug issues
if ! zplug check; then
  zplug install
fi
zplug load

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
