#!/usr/bin/env bash

source ~/.dotfiles/config/shared/rc.sh
source ~/.dotfiles/config/shared/rc.bash

# Path to the bash it configuration
export BASH_IT="$HOME/.bash_it"

# Lock and Load a custom theme file
export BASH_IT_THEME="$HOME/.dotfiles/config/bash_it/pure_prompt.bash"

# Don't check mail when opening terminal.
unset MAILCHECK

# Change this to your console based IRC client of choice.
export IRC_CLIENT='irssi'

# Set this to the command you use for todo.txt-cli
export TODO="t"

# Set this to false to turn off version control status checking within the prompt for all themes
export SCM_CHECK=true

# Load Bash It
source "$BASH_IT"/bash_it.sh

source ~/.dotfiles/config/shared/ssh-agent-connect.bash
