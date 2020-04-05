# Start graphical server if i3 not already running.
if is_linux && [ "$(tty)" = '/dev/tty1' ]; then
  pgrep -x i3 || exec startx
fi
