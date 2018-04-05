#!/bin/sh

battery_print() {
  path_ac="/sys/class/power_supply/ADP1"
  path_battery_0="/sys/class/power_supply/BAT0"
  path_battery_1="/sys/class/power_supply/BAT1"
  check_ac="online"
  check_battery_now="charge_now"
  check_battery_full="charge_full"

  ac=0
  battery_level_0=0
  battery_level_1=0
  battery_max_0=0
  battery_max_1=0

  if [ -f "$path_ac/$check_ac" ]; then
    ac=$(cat "$path_ac/$check_ac")
  fi

  if [ -f "$path_battery_0/$check_battery_now" ]; then
    battery_level_0=$(cat "$path_battery_0/$check_battery_now")
  fi

  if [ -f "$path_battery_0/$check_battery_full" ]; then
    battery_max_0=$(cat "$path_battery_0/$check_battery_full")
  fi

  if [ -f "$path_battery_1/$check_battery_now" ]; then
    battery_level_1=$(cat "$path_battery_1/$check_battery_now")
  fi

  if [ -f "$path_battery_1/$check_battery_full" ]; then
    battery_max_1=$(cat "$path_battery_1/$check_battery_full")
  fi

  battery_level=$(("$battery_level_0 + $battery_level_1"))
  battery_max=$(("$battery_max_0 + $battery_max_1"))

  battery_percent=$(("$battery_level * 100"))
  battery_percent=$(("$battery_percent / $battery_max"))

  if [ "$ac" -eq 1 ]; then
    icon=""

    if [ "$battery_percent" -gt 97 ]; then
      echo "$icon"
    else
      echo "$icon $battery_percent %"
    fi
  else
    if [ "$battery_percent" -gt 85 ]; then
      icon=" "
    elif [ "$battery_percent" -gt 60 ]; then
      icon=""
    elif [ "$battery_percent" -gt 35 ]; then
      icon=""
    elif [ "$battery_percent" -gt 10 ]; then
      icon=""
    else
      icon=""
    fi

    echo "$icon $battery_percent %"
  fi
}

case "$1" in
  --update)
    pid=$(pgrep -xf "/bin/sh /home/user/.config/polybar/scripts/battery-combined-udev.sh")

    if [ "$pid" != "" ]; then
      kill -10 "$pid"
    fi
    ;;
  *)
    trap exit INT
    trap "echo" USR1

    while true; do
      battery_print

      sleep 30 &
      wait
    done
    ;;
esac
