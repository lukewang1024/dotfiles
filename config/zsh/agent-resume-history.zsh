# Put an agent's exact resume command at the top of zsh history when its TUI exits.

_agent_add_history() {
  local entry=$1

  # Programmatic history insertion is not reliably imported into the live
  # fc -p stack by per-directory-history. Let the next Up key consume this
  # entry directly; subsequent Up presses retain their normal behavior.
  _agent_pending_resume=$entry

  # The per-directory-history plugin owns both the live history stack and two
  # backing files. Use its hook when loaded so Up sees the entry immediately.
  if (( $+functions[_per-directory-history-addhistory] )); then
    _per-directory-history-addhistory "$entry"
  else
    print -Sr -- "$entry"
  fi
}

_agent_history_up() {
  if [ -n "${_agent_pending_resume:-}" ] && [ -z "$BUFFER" ]; then
    BUFFER=$_agent_pending_resume
    CURSOR=${#BUFFER}
    _agent_pending_resume=
  else
    zle history-substring-search-up
  fi
}
zle -N _agent_history_up

_agent_bind_history_up() {
  bindkey '^[[A' _agent_history_up
  bindkey '^[OA' _agent_history_up
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _agent_bind_history_up
_agent_bind_history_up

_agent_stat_time() {
  local kind=$1 file=$2 value= bsd_format= gnu_format=

  case "$kind" in
    birth)
      bsd_format='%B'
      gnu_format='%W'
      ;;
    mtime)
      bsd_format='%m'
      gnu_format='%Y'
      ;;
    *)
      return 1
      ;;
  esac

  value=$(stat -f "$bsd_format" "$file" 2>/dev/null)
  case "$value" in
    ''|*[!0-9]*) value=$(stat -c "$gnu_format" "$file" 2>/dev/null) ;;
  esac
  case "$value" in
    ''|*[!0-9]*) return 1 ;;
  esac
  if [ "$kind" = birth ] && [ "$value" -eq 0 ]; then
    _agent_stat_time mtime "$file"
    return
  fi
  printf '%s\n' "$value"
}

_agent_session_id_from_jsonl() {
  local root=$1 marker=$2 session_cwd=$3 file file_cwd birth marker_mtime newest_birth=0 newest=
  local -a files

  [ -d "$root" ] || return 1
  marker_mtime=$(_agent_stat_time mtime "$marker") || return 1
  files=("${(@f)$(find "$root" -type f -name 'rollout-*.jsonl' -newer "$marker" -print 2>/dev/null)}")
  for file in "${files[@]}"; do
    [ -n "$file" ] || continue
    file_cwd=$(head -n 1 "$file" | jq -r '.payload.cwd // empty' 2>/dev/null)
    [ "$file_cwd" = "$session_cwd" ] || continue
    birth=$(_agent_stat_time birth "$file") || continue
    [ "$birth" -ge "$marker_mtime" ] || continue
    if [ "$birth" -ge "$newest_birth" ]; then
      newest_birth=$birth
      newest=${file:t:r}
      newest=${newest##*-}
      # A UUID contains hyphens, so take it from the session metadata instead.
      newest=$(head -n 1 "$file" | jq -r '.payload.session_id // .payload.id // empty' 2>/dev/null)
    fi
  done
  [ -n "$newest" ] && printf '%s\n' "$newest"
}

_agent_claude_session_id() {
  local marker=$1 session_cwd=$2 file file_cwd birth marker_mtime newest_birth=0 newest=
  local -a files

  [ -d "$HOME/.claude/projects" ] || return 1
  marker_mtime=$(_agent_stat_time mtime "$marker") || return 1
  files=("${(@f)$(find "$HOME/.claude/projects" -mindepth 2 -maxdepth 2 -type f -name '*.jsonl' -newer "$marker" -print 2>/dev/null)}")
  for file in "${files[@]}"; do
    [ -n "$file" ] || continue
    file_cwd=$(tail -n 40 "$file" | jq -r 'select(.cwd != null) | .cwd' 2>/dev/null | tail -n 1)
    [ "$file_cwd" = "$session_cwd" ] || continue
    birth=$(_agent_stat_time birth "$file") || continue
    [ "$birth" -ge "$marker_mtime" ] || continue
    if [ "$birth" -ge "$newest_birth" ]; then
      newest_birth=$birth
      newest=${file:t:r}
    fi
  done
  [ -n "$newest" ] && printf '%s\n' "$newest"
}

_agent_run_and_remember() {
  setopt localtraps
  local agent=$1 executable=$2 resume_prefix=$3 session_root=$4
  shift 4
  local session_cwd=$PWD marker exit_status=0 interrupted=0 session_id= marker_mtime escaped_cwd opencode_db

  _agent_pending_resume=
  marker=$(mktemp "${TMPDIR:-/tmp}/agent-resume.XXXXXX") || return 1
  # Ctrl-C kills the child TUI and would normally abort the rest of this shell
  # function too. Keep the trap local so cleanup and history insertion still run.
  trap 'interrupted=1' INT
  command "$executable" "$@"
  exit_status=$?
  [ "$interrupted" -eq 1 ] && exit_status=130

  case "$agent" in
    claude)
      session_id=$(_agent_claude_session_id "$marker" "$session_cwd")
      ;;
    opencode)
      marker_mtime=$(_agent_stat_time mtime "$marker")
      escaped_cwd=$(printf '%s' "$session_cwd" | sed "s/'/''/g")
      opencode_db="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db"
      session_id=$(sqlite3 "$opencode_db" \
        "select id from session where directory = '$escaped_cwd' and time_updated >= $((marker_mtime * 1000)) order by time_updated desc limit 1;" \
        2>/dev/null)
      ;;
    *)
      session_id=$(_agent_session_id_from_jsonl "$session_root" "$marker" "$session_cwd")
      ;;
  esac
  rm -f "$marker"

  [ -n "$session_id" ] && _agent_add_history "$resume_prefix $session_id"
  return "$exit_status"
}

unalias codex claude traex opencode 2>/dev/null
codex() {
  local arg has_yolo=0
  for arg in "$@"; do
    [ "$arg" = "--yolo" ] && has_yolo=1
  done
  if [ "$has_yolo" -eq 1 ]; then
    _agent_run_and_remember codex "$HOME/.local/bin/codex" 'codex --yolo resume' "$HOME/.codex/sessions" "$@"
  else
    _agent_run_and_remember codex "$HOME/.local/bin/codex" 'codex resume' "$HOME/.codex/sessions" "$@"
  fi
}
claude() {
  local arg has_bypass=0
  for arg in "$@"; do
    [ "$arg" = "--dangerously-skip-permissions" ] && has_bypass=1
  done
  if [ "$has_bypass" -eq 1 ]; then
    _agent_run_and_remember claude "$HOME/.local/bin/claude" 'claude --dangerously-skip-permissions --resume' '' "$@"
  else
    _agent_run_and_remember claude "$HOME/.local/bin/claude" 'claude --resume' '' "$@"
  fi
}
traex() {
  _agent_run_and_remember traex "$HOME/.local/bin/traex" 'traex resume' "$HOME/.trae/cli/sessions" "$@"
}
opencode() {
  local arg has_auto=0
  for arg in "$@"; do
    [ "$arg" = "--auto" ] && has_auto=1
  done
  if [ "$has_auto" -eq 1 ]; then
    _agent_run_and_remember opencode /opt/homebrew/bin/opencode 'opencode --auto --session' '' "$@"
  else
    _agent_run_and_remember opencode /opt/homebrew/bin/opencode 'opencode --session' '' "$@"
  fi
}
