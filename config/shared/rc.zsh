export SHELL=$(command -v zsh)

ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_USE_ASYNC=1
PURE_PROMPT_SYMBOL=λ
PURE_GIT_DOWN_ARROW=▼
PURE_GIT_UP_ARROW=▲

bindkey '^[OA' history-substring-search-up   # Up arrow key
bindkey '^[OB' history-substring-search-down # Down arrow key
bindkey -M emacs '^P' history-substring-search-up
bindkey -M emacs '^N' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

alias rrc='source ~/.zshrc && rehash'
alias upenv='zgen update && nodenv update && pyenv update && rbenv update'
