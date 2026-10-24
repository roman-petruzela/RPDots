#!/usr/bin/env bash
set -euo pipefail

CURRENT_WALL="$HOME/.local/share/wallpapers/current"

command -v awww-daemon >/dev/null 2>&1 || exit 0

restarted=0
if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon >/dev/null 2>&1 &
    sleep 0.5
    restarted=1
fi

if [[ -f "$CURRENT_WALL" ]]; then
    awww img "$CURRENT_WALL" \
        --transition-type "${WALL_TRANSITION_TYPE:-wave}" \
        --transition-angle "${WALL_TRANSITION_ANGLE:-45}" \
        --transition-wave "${AWWW_TRANSITION_WAVE:-40,30}" \
        --transition-step "${WALL_TRANSITION_STEP:-10}" \
        --transition-fps "${WALL_TRANSITION_FPS:-120}" >/dev/null 2>&1 || true
fi

if [[ -x "$HOME/.local/bin/wallpaper-video-ctl.sh" ]]; then
    if [[ "$restarted" == 1 ]]; then
        "$HOME/.local/bin/wallpaper-video-ctl.sh" sync >/dev/null 2>&1 || true
    else
        "$HOME/.local/bin/wallpaper-video-ctl.sh" ensure >/dev/null 2>&1 || true
    fi
fi

