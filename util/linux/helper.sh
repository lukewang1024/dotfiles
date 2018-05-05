exists()
{
  command -v "$1" >/dev/null 2>&1
}

dmenu_filter()
{
  cmd="echo -e \"$1\""
  exists rofi && cmd="$cmd | rofi -dmenu" || cmd="$cmd | dmenu -i"
  [[ -n $2 ]] && cmd="$cmd -p \"$2\""
  eval "$cmd"
}
