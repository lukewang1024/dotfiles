#!/usr/bin/env bash

# Run powerline-daemon if exists
which powerline-daemon &> /dev/null && powerline-daemon -q

# Load powerline config if exists, otherwise load custom theme
powerlineConfig=$(python -m site --user-site)/powerline/bindings/tmux/powerline.conf

if [ -f $powerlineConfig ]; then
  tmux source-file $powerlineConfig
else
  # status line formatting
  tmux set-option -g status on
  tmux set-option -g -q status-utf8 on
  tmux set-option -g status-interval 5 # default = 15 seconds
  tmux set-option -g status-justify centre

  # administrative debris (session name, hostname, time) in status bar
  tmux set-option -g status-left " #[bg=colour33]##[fg=white,bold]#(hostname -s) #[fg=white,nobold]s[#S]:w[#I].p[#P]#[default]"
  tmux set-option -g status-left-length 100
  tmux set-option -g status-right "#[fg=default]%a %h-%d %H:%M "
  tmux set-option -g status-right-length 100

  # Status Bar Colors
  tmux set-option -g status-style fg=colour250,bg=colour237 # default for whole status line (246, 233)
  tmux set-option -g status-left-style fg=white,bold,bg=colour233
  tmux set-option -g status-right-style fg=colour75,none,bg=colour233

  # Message Colors
  tmux set-option -g message-style fg=colour15,bold,bg=colour166 # 2,default

  # Window Status Colors
  tmux set-window-option -g window-status-style default # default for all window statuses
  tmux set-window-option -g window-status-last-style fg=default,bg=colour235
  tmux set-window-option -g window-status-current-style fg=colour15,bold,bg=colour166 # white, 63
  tmux set-window-option -g window-status-bell-style default
  tmux set-window-option -g window-status-activity-style fg=white,none,bg=colour196

  tmux set-window-option -g window-status-format ' #I #W ' # Default is '#I:#W#F'
  tmux set-window-option -g window-status-current-format ' #I #W ' # Default is '#I:#W#F'
fi
