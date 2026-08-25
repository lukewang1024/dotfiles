# Compatibility fixes for Oh My Zsh's per-directory-history plugin.
# Keep this separate from Zinit's cache so plugin updates cannot overwrite it.

zmodload zsh/datetime

_per-directory-history-addhistory() {
  # A zshaddhistory hook returning non-zero tells zsh that the hook has handled
  # the entry. This prevents zsh from adding it a second time after print -Sr.
  if [[ -o hist_ignore_space && "$1" == \ * ]]; then
    return 1
  fi

  local entry=${1%%$'\n'}
  # fc -AI marks an event as written, so invoking it for two different files
  # can leave the second file empty. Append the serialized entry to each file
  # independently, while print -Sr keeps the live history list in sync.
  local serialized=${entry//$'\n'/$'\\\n'}
  if [[ -o extended_history ]]; then
    serialized=": $EPOCHSECONDS:0;$serialized"
  fi
  mkdir -p "${HISTFILE:h}" "${_per_directory_history_directory:h}"
  print -r -- "$serialized" >> "$HISTFILE"
  print -r -- "$serialized" >> "$_per_directory_history_directory"
  print -Sr -- "$entry"
  return 1
}

_per-directory-history-set-directory-history() {
  mkdir -p "${_per_directory_history_directory:h}"
  : >> "$_per_directory_history_directory"

  local original_histsize=$HISTSIZE
  HISTSIZE=0
  HISTSIZE=$original_histsize
  fc -R "$_per_directory_history_directory"
  fc -p "$_per_directory_history_directory"
}

_per-directory-history-change-directory() {
  _per_directory_history_directory="$HISTORY_BASE${PWD:A}/history"
  mkdir -p "${_per_directory_history_directory:h}"
  : >> "$_per_directory_history_directory"

  if [[ $_per_directory_history_is_global == false ]]; then
    local prev="$HISTORY_BASE${OLDPWD:A}/history"
    mkdir -p "${prev:h}"
    : >> "$prev"

    local original_histsize=$HISTSIZE
    HISTSIZE=0
    HISTSIZE=$original_histsize
    fc -R "$_per_directory_history_directory"
  fi
}

_per-directory-history-set-global-history() {
  mkdir -p "${HISTFILE:h}"
  : >> "$HISTFILE"

  local original_histsize=$HISTSIZE
  HISTSIZE=0
  HISTSIZE=$original_histsize
  fc -R "$HISTFILE"
  fc -p "$HISTFILE"
}
