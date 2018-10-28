if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi

# Start graphical server if i3 not already running.
if [[ "$OSTYPE" == 'linux-gnu' && "$(tty)" == '/dev/tty1' ]]; then
  pgrep -x i3 || exec startx
fi
