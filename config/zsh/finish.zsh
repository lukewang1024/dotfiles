# Workbench owns attachment history; this file only opts SSH logins in.
if is_ssh && ! is_tmux; then
  if command -v tmux-agent-workbench >/dev/null 2>&1; then
    tmux-agent-workbench client attach
  else
    tmux attach-session || tmux new-session
  fi
fi

source "$config_dir/sh/profile.sh"

# anyenv: lazy-load to keep shell startup fast. `anyenv init -` forks every managed
# *env (goenv/pyenv/nodenv/rbenv) on each shell (~800ms). Instead, put each env's
# shims + bin on PATH now so `go`/`python`/`node`/`ruby` and the managers resolve
# immediately, and defer full shell integration (env functions, completions) until
# the first time a manager command is actually run.
if exists anyenv; then
  for _dir in "$ANYENV_ROOT"/envs/*/shims(/N) "$ANYENV_ROOT"/envs/*/bin(/N); do
    path=("$_dir" $path)
  done
  unset _dir

  _anyenv_lazy_init() {
    local _m
    for _m in anyenv "$ANYENV_ROOT"/envs/*(/N:t); do
      unfunction "$_m" 2>/dev/null
    done
    unfunction _anyenv_lazy_init
    eval "$(command anyenv init -)"
  }
  for _m in anyenv "$ANYENV_ROOT"/envs/*(/N:t); do
    eval "${_m}() { _anyenv_lazy_init; ${_m} \"\$@\"; }"
  done
  unset _m
fi

# Load pyenv-virtualenv properly
# https://github.com/pyenv/pyenv-virtualenv/issues/259#issuecomment-1096144748
# This line is quite slow. Disable it for now.
# exists pyenv && eval "$(pyenv virtualenv-init - | sed s/precmd/chpwd/g)"
