#!/usr/bin/env bash
action="${1:-up}"

case "$action" in
    up)   brightnessctl --class=backlight set +10% >/dev/null 2>&1 ;;
    down) brightnessctl --class=backlight set 10%- >/dev/null 2>&1 ;;
esac

"$HOME/.local/bin/rp-shell" osd-brightness trigger || true
