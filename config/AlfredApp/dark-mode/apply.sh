#!/bin/sh
# apply.sh toggle|light|dark — set the macOS system appearance.
#
# That is deliberately ALL it does. Everything downstream — the shared state file
# nvim watches, Alacritty's imported theme, tmux, and any SSH devbox we're
# attached to — already hangs off the OS appearance via the `appearance-daemon`
# LaunchAgent (dark-notify). Flipping the OS switch is the
# one event those watchers exist to observe, so re-implementing the fan-out here
# would give the Alfred path its own private, second-best copy of a chain that is
# already correct for every OTHER way the appearance changes (Control Centre,
# System Settings, sunrise/sunset auto).
#
# The one exception is the fallback at the bottom: if the daemon is not loaded on
# this machine, nothing is listening, so drive `theme-sync` directly.
#
# POSIX sh — runs from Alfred's minimal environment.
set -u

PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

current() {
	# AppleInterfaceStyle reads "Dark" in dark mode and is simply absent in
	# light mode — there is no "Light" value to match on.
	if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
		echo dark
	else
		echo light
	fi
}

cur=$(current)

case "${1:-toggle}" in
toggle)
	if [ "$cur" = dark ]; then want=light; else want=dark; fi
	;;
light | dark)
	want=$1
	;;
*)
	echo "apply.sh: usage: ${0##*/} [toggle|light|dark]" >&2
	exit 2
	;;
esac

if [ "$want" = "$cur" ]; then
	printf '%s\n' "$want"
	exit 0
fi

[ "$want" = dark ] && flag=true || flag=false
osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $flag" || {
	echo "apply.sh: could not set appearance (Alfred may need Automation permission for System Events)" >&2
	exit 1
}

# Fallback for a machine where the appearance daemon was never installed: with no
# dark-notify watcher running, the OS switch reaches nobody, so fan out by hand.
# `theme-sync <want>` is the same reconcile the daemon would have triggered, and
# it is idempotent — so on a machine that DOES run the daemon this stays off.
if ! launchctl list com.lukew.appearance >/dev/null 2>&1; then
	command -v theme-sync >/dev/null 2>&1 && theme-sync "$want" >/dev/null 2>&1 &
fi

printf '%s\n' "$want"
