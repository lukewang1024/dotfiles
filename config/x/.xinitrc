#!/usr/bin/env bash
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources

command -v kbmod >/dev/null 2>&1 && kbmod

export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

exec i3
