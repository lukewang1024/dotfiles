source ~/.zplug/init.zsh

source ~/.dotfiles/config/shared/rc.sh

# oh-my-zsh plugins
zplug 'robbyrussell/oh-my-zsh', use:'lib/*.zsh'
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
zplug 'plugins/npm', from:oh-my-zsh
zplug 'plugins/per-directory-history', from:oh-my-zsh
zplug 'plugins/sudo', from:oh-my-zsh
zplug 'plugins/tmux', from:oh-my-zsh
zplug 'plugins/tmuxinator', from:oh-my-zsh, lazy:yes
zplug 'plugins/urltools', from:oh-my-zsh
zplug 'plugins/yarn', from:oh-my-zsh

zplug 'supercrabtree/k'

# completions
zplug 'zsh-users/zsh-autosuggestions'
zplug 'zsh-users/zsh-completions'
zplug 'esc/conda-zsh-completion'

# theme - pure
zplug 'mafredri/zsh-async'
zplug 'sindresorhus/pure', use:pure.zsh, as:theme

# OS specific plugins

if [[ $OSTYPE == 'cygwin' ]]; then
  zplug 'plugins/cygwin', from:oh-my-zsh
else # *nix
  zplug 'plugins/colorize', from:oh-my-zsh
  zplug 'plugins/docker', from:oh-my-zsh
  zplug 'plugins/vagrant', from:oh-my-zsh

  # env managers
  zplug 'plugins/rbenv', from:oh-my-zsh
  zplug 'plugins/pyenv', from:oh-my-zsh
  zplug 'plugins/jenv', from:oh-my-zsh
  zplug 'jsahlen/nodenv.plugin.zsh'
fi

if [[ $OSTYPE == *'darwin'* ]]; then
  zplug 'plugins/osx', from:oh-my-zsh
  zplug 'plugins/brew', from:oh-my-zsh
fi

if [[ $OSTYPE == 'linux-gnu' ]]; then
  zplug 'plugins/archlinux', from:oh-my-zsh, if:'[ -f /etc/arch-release ]'
  zplug 'plugins/ubuntu', from:oh-my-zsh, if:'[ -f /etc/debian_version ]'
  zplug 'plugins/fedora', from:oh-my-zsh, if:'[ -f /etc/fedora-release ]'
fi

zplug 'zsh-users/zsh-syntax-highlighting', defer:2
zplug 'zsh-users/zsh-history-substring-search', defer:3, \
  hook-load:'source ~/.dotfiles/config/shared/rc.zsh; source ~/.dotfiles/config/todoist/todoist_functions.sh'

# Tip: Use `--verbose` upon `check` and `load` to debug issues
if ! zplug check; then
  zplug install
fi
zplug load

[ -f ~/.zshrc.local ] && source ~/.zshrc.local

source ~/.dotfiles/config/shared/ssh-agent-connect.zsh
