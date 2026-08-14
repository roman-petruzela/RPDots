#!/usr/bin/env bash
action="${1:-up}"

case "$action" in
    up)   brightnessctl --class=backlight set +10% >/dev/null 2>&1 ;;
    down) brightnessctl --class=backlight set 10%- >/dev/null 2>&1 ;;
esac

# Hodnotu si OSD načte samo z brightnessctl — `qs ipc call` v quickshellu
# 0.3.0 neumí předat argument.
qs ipc call osd-brightness trigger >/dev/null 2>&1 || true
