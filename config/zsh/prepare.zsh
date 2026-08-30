# Reuse agent forwarding in SSH sessions; otherwise connect to the machine's
# stable per-user agent socket (creating the underlying agent when necessary).
source "$config_dir/zsh/ssh-agent-connect.zsh"

# The default `pyenv virtualenv-init -` in pyenv plugin could slow down prompt
# drastically. Disable it.
ZSH_PYENV_VIRTUALENV=false

# oh-my-zsh runs compinit for us. Skip its compaudit security scan (compfix): on a
# personal machine it's safe, and it cuts the occasional compdump *rebuild* from
# ~13s to ~2s. Normal warm startups already reuse the cached dump (~40ms) regardless.
ZSH_DISABLE_COMPFIX=true
