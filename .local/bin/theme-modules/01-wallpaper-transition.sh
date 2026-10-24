#!/usr/bin/env bash
set -euo pipefail

CURRENT_WALL="${HOME}/.local/share/wallpapers/current"

[[ "${WALLPAPER_TRANSITION_DONE:-}" == "1" ]] && exit 0
[[ -f "$CURRENT_WALL" ]] || exit 0

if command -v awww >/dev/null 2>&1; then
    awww img "$CURRENT_WALL" \
        --transition-type "${WALL_TRANSITION_TYPE:-wave}" \
        --transition-angle "${WALL_TRANSITION_ANGLE:-45}" \
        --transition-wave "${AWWW_TRANSITION_WAVE:-40,30}" \
        --transition-pos "${AWWW_TRANSITION_POS:-0.5,0.5}" \
        --transition-step "${WALL_TRANSITION_STEP:-10}" \
        --transition-fps "${WALL_TRANSITION_FPS:-120}" >/dev/null 2>&1 \
        || awww img "$CURRENT_WALL" >/dev/null 2>&1 || true
fi

ctl="$HOME/.local/bin/wallpaper-video-ctl.sh"
[[ -x "$ctl" ]] && setsid "$ctl" sync >/dev/null 2>&1 </dev/null &
exit 0
