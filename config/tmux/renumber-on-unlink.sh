#!/bin/sh
# Extend renumber-windows to cross-session moves without changing explicit
# window positions within the same session.
set -eu

socket=$1
source_session=$2
unlinked_window=$3

# Moving the last window destroys its source session. Respect a per-session
# override of renumber-windows as well as the inherited global setting.
setting=$(tmux -S "$socket" display-message -p -t "$source_session:" '#{renumber-windows}' 2>/dev/null) || exit 0
[ "$setting" = 1 ] || exit 0

# A window moved to another index in the same session is still linked there.
if tmux -S "$socket" list-windows -t "$source_session" -F '#{window_id}' 2>/dev/null |
    grep -Fxq "$unlinked_window"; then
    exit 0
fi

# The session may have disappeared while the hook was running.
tmux -S "$socket" move-window -r -t "$source_session:" 2>/dev/null || :
