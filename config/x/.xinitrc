#!/usr/bin/env sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

# =============================================================================
# Utility functions
# =============================================================================

exists() { command -v "$1" >/dev/null 2>&1; }
running() { pgrep -x "$1" >/dev/null 2>&1; }
to_launch() { exists "$1" && ! running "$1"; }

is_vnc_session() {
  # VNC sessions typically have DISPLAY starting with high numbers (:1, :2, etc.)
  # or we can check for VNC-specific environment/process
  [ -n "$VNCDESKTOP" ] || pgrep -x "Xvnc" >/dev/null 2>&1
}

# =============================================================================
# Init functions by category
# =============================================================================

init_common() {
  # Resources and environment - needed for all sessions
  [ -f ~/.Xresources ] && xrdb -merge ~/.Xresources

  export GTK_IM_MODULE=fcitx
  export QT_IM_MODULE=fcitx
  export XMODIFIERS=@im=fcitx
  export XDG_SESSION_TYPE=x11
  export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
  export QT_QPA_PLATFORMTHEME="qt5ct"

  # System xinitrc.d scripts
  if [ -d /etc/X11/xinit/xinitrc.d ]; then
    for f in /etc/X11/xinit/xinitrc.d/*; do
      [ -x "$f" ] && . "$f"
    done
    unset f
  fi

  # Keyboard tweaks - essential for all sessions
  exists kbmod && kbmod
}

init_local() {
  # Daemons only needed on local machine (not VNC)

  # Session management
  to_launch lxsession && lxsession &
  # Automatic display management
  to_launch mons && mons -a &
  # Synaptic daemon (touchpad)
  to_launch syndaemon && syndaemon -k &
  # Screensaver daemon
  to_launch xscreensaver && xscreensaver &
  # Clipboard manager
  to_launch greenclip && greenclip daemon &
  # Composite manager
  to_launch picom && picom --fading &
  # Hide mouse when idle
  to_launch unclutter && unclutter &
  # Downloader
  to_launch aria2c && aria2c &
  # HTTP proxy
  local-http-proxy &

  # Tray applets
  to_launch pa-applet && pa-applet &
  to_launch nm-applet && nm-applet &
  to_launch blueman-applet && blueman-applet &
  to_launch udiskie && udiskie --tray &
  to_launch redshift-gtk && PATH=/usr/bin redshift-gtk &

  # Cloud sync
  to_launch dropbox && dropbox &
}

init_remote() {
  # Remote/VNC session specific initialization
  # Currently no VNC-specific daemons needed
  :
}

# =============================================================================
# Session launchers
# =============================================================================

start_i3() {
  exists wallpaper && wallpaper
  exec i3
}

start_xfce() {
  to_launch plank && plank &
  exec startxfce4
}

# =============================================================================
# Main
# =============================================================================

main() {
  local session=${1:-xfce}

  # Common init for all sessions
  init_common

  # Environment-specific init
  if is_vnc_session; then
    init_remote
  else
    init_local
  fi

  # Start selected session
  case $session in
    i3|i3wm)
      start_i3
      ;;
    xfce|xfce4)
      start_xfce
      ;;
    *)
      # Unknown session, try to run it as command
      exec $session
      ;;
  esac
}

main "$@"
