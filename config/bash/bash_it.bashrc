config_dir="$HOME/.dotfiles/config"

source "$config_dir/sh/rc.sh"

# Path to the bash it configuration
export BASH_IT="$HOME/.bash_it"

# Lock and Load a custom theme file
export BASH_IT_THEME="$config_dir/bash/pure_prompt.bash"

# Don't check mail when opening terminal.
unset MAILCHECK

# Change this to your console based IRC client of choice.
export IRC_CLIENT='irssi'

# Set this to the command you use for todo.txt-cli
export TODO="t"

# Set this to false to turn off version control status checking within the prompt for all themes
export SCM_CHECK=true

# Load Bash It
source "$BASH_IT/bash_it.sh"

source "$config_dir/bash/rc.bash"

# Config ssh-agent on local machine
[ -z "$SSH_CLIENT" ] && source "$config_dir/bash/ssh-agent-connect.bash"

# Launch tmux on remote session
[ -n "$SSH_CLIENT" ] && [ -z "$TMUX" ] && tmux