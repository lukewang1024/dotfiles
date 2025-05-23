#!/usr/bin/env sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

exists() { command -v "$1" >/dev/null 2>&1; }
running() { pgrep -x "$1" >/dev/null 2>&1; }
to_launch() { exists "$1" && ! running "$1"; }

[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources

export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

export XDG_SESSION_TYPE=x11

export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
export QT_QPA_PLATFORMTHEME="qt5ct"

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
  for f in /etc/X11/xinit/xinitrc.d/* ; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# session management
to_launch lxsession && lxsession &
# automatic display management
to_launch mons && mons -a &
# synaptic daemon
to_launch syndaemon && syndaemon -k &
# xscreensaver daemon
to_launch xscreensaver && xscreensaver &
# greenclip daemon
to_launch greenclip && greenclip daemon &
# composite manager
to_launch picom && picom --fading &
# unclutter makes the mouse invisible after a brief period
to_launch unclutter && unclutter &
# downloader
to_launch aria2c && aria2c &
# privoxy / polipo for HTTP proxy
local-http-proxy &

# volume tray applet
to_launch pa-applet && pa-applet &
# network manager tray applet
to_launch nm-applet && nm-applet &
# bluetooth manager tray applet
to_launch blueman-applet && blueman-applet &
# disk management tray applet
to_launch udiskie && udiskie --tray &
# redshift with tray applet (specify path to avoid using python3 from linuxbrew)
to_launch redshift-gtk && PATH=/usr/bin redshift-gtk &

# dropbox
to_launch dropbox && dropbox &

# a set of key tweaks
exists kbmod && kbmod

session=${1:-xfce}

case $session in
  i3|i3wm)
    # set wallpaper and lockscreen image
    exists wallpaper && wallpaper
    # start i3
    exec i3
    ;;
  xfce|xfce4)
    # dock
    to_launch plank && plank &
    # start xfce
    exec startxfce4
    ;;
  *)
    # No known session, try to run it as command
    exec $1
    ;;
esac
