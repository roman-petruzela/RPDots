#!/usr/bin/env bash
action="${1:-up}"

case "$action" in
    up)   wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02+ -l 1.0 ;;
    down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02- ;;
    mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
esac

muted="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -c MUTED || true)"
vol="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%.0f", $2 * 100}')"

if [[ "$muted" -gt 0 ]]; then
    qs ipc call osd-volume show muted 2>/dev/null || true
else
    qs ipc call osd-volume show "$vol" 2>/dev/null || true
fi
