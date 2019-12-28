config_dir="$HOME/.dotfiles/config"

source ~/.zplug/init.zsh

source "$config_dir/sh/rc.sh"

# oh-my-zsh plugins
zplug 'robbyrussell/oh-my-zsh', use:'lib/*.zsh'
zplug 'plugins/colored-man-pages', from:oh-my-zsh
zplug 'plugins/command-not-found', from:oh-my-zsh
zplug 'plugins/common-aliases', from:oh-my-zsh
zplug 'plugins/copybuffer', from:oh-my-zsh
zplug 'plugins/copydir', from:oh-my-zsh
zplug 'plugins/copyfile', from:oh-my-zsh
zplug 'plugins/cp', from:oh-my-zsh
zplug 'plugins/dircycle', from:oh-my-zsh
zplug 'plugins/emoji', from:oh-my-zsh
zplug 'plugins/encode64', from:oh-my-zsh
zplug 'plugins/extract', from:oh-my-zsh
zplug 'plugins/fancy-ctrl-z', from:oh-my-zsh
zplug 'plugins/fasd', from:oh-my-zsh
zplug 'plugins/fd', from:oh-my-zsh
zplug 'plugins/fzf', from:oh-my-zsh
zplug 'plugins/git', from:oh-my-zsh
zplug 'plugins/git-extras', from:oh-my-zsh
zplug 'plugins/git-flow', from:oh-my-zsh
zplug 'plugins/git-flow-avh', from:oh-my-zsh
zplug 'plugins/gitfast', from:oh-my-zsh
zplug 'plugins/gitignore', from:oh-my-zsh
zplug 'plugins/globalias', from:oh-my-zsh
zplug 'plugins/golang', from:oh-my-zsh
zplug 'plugins/history', from:oh-my-zsh
zplug 'plugins/httpie', from:oh-my-zsh
zplug 'plugins/npm', from:oh-my-zsh
zplug 'plugins/per-directory-history', from:oh-my-zsh
zplug 'plugins/rsync', from:oh-my-zsh
zplug 'plugins/sudo', from:oh-my-zsh
zplug 'plugins/systemadmin', from:oh-my-zsh
zplug 'plugins/taskwarrior', from:oh-my-zsh
zplug 'plugins/tig', from:oh-my-zsh
zplug 'plugins/timer', from:oh-my-zsh
zplug 'plugins/tmux', from:oh-my-zsh
zplug 'plugins/tmuxinator', from:oh-my-zsh, lazy:yes
zplug 'plugins/urltools', from:oh-my-zsh
zplug 'plugins/vscode', from:oh-my-zsh
zplug 'plugins/web-search', from:oh-my-zsh
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

if [[ $OSTYPE == 'darwin'* ]]; then
  zplug 'plugins/osx', from:oh-my-zsh
  zplug 'plugins/brew', from:oh-my-zsh
  zplug 'plugins/forklift', from:oh-my-zsh
fi

if [[ $OSTYPE == 'linux-gnu' ]]; then
  if [ -f /etc/arch-release ]; then
    zplug 'plugins/archlinux', from:oh-my-zsh
    zplug "/usr/share/doc/pkgfile/command-not-found.zsh", from:local
  elif [ -f /etc/debian_version ]; then
    if [[ $(lsb_release -i | cut -c17-) == 'Ubuntu' ]]; then
      zplug 'plugins/ubuntu', from:oh-my-zsh
    fi
  elif [ -f /etc/fedora-release ]; then
    zplug 'plugins/dnf', from:oh-my-zsh
  fi
fi

if [ -f ~/.zshrc.local ]; then
  zplug '~/.zshrc.local', from:local
fi

zplug 'zsh-users/zsh-syntax-highlighting', defer:2
zplug 'zsh-users/zsh-history-substring-search', defer:3, \
  hook-load:"source $config_dir/zsh/rc.zsh; source $config_dir/todoist/todoist_functions.sh"

# Tip: Use `--verbose` upon `check` and `load` to debug issues
if ! zplug check; then
  zplug install
fi
zplug load

# Config ssh-agent on local machine
[ -z "$SSH_CLIENT" ] && source "$config_dir/zsh/ssh-agent-connect.zsh"

# Launch tmux on remote session
[ -n "$SSH_CLIENT" ] && [ -z "$TMUX" ] && tmux
