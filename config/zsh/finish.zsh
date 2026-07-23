# Launch tmux on remote session — attach to an existing session if one is
# detached, else start a fresh one. Can't lean on OMZ tmux's autoconnect alias:
# that plugin is Turbo-deferred (loads after the first prompt) while this snippet
# runs synchronously, so the alias isn't defined yet and a bare `tmux` would just
# `new-session` every login. Spell out attach-or-create so it's load-order-proof.
is_ssh && ! is_tmux && { tmux attach || tmux new-session; }

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

# Load customized p10k prompt
exists p10k && [ -f "${ZDOTDIR:-~}/.p10k.zsh" ] && source "${ZDOTDIR:-~}/.p10k.zsh"
