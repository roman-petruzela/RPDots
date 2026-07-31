#!/usr/bin/env bash
action="${1:-up}"

case "$action" in
    up)   brightnessctl --class=backlight set +10% >/dev/null 2>&1 ;;
    down) brightnessctl --class=backlight set 10%- >/dev/null 2>&1 ;;
esac

val="$(brightnessctl --class=backlight -m 2>/dev/null | awk -F',' '{gsub(/%/,"",$4); printf "%.0f", $4}' || echo 0)"
qs ipc call osd-brightness show "$val" 2>/dev/null || true
