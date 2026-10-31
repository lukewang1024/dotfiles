# All platforms use the shared Starship configuration linked by basic setup.
PROMPT='%n@%m:%~%# '
if exists starship; then
  eval "$(starship init zsh --print-full-init)"
fi
