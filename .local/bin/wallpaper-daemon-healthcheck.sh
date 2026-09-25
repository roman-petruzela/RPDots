#!/usr/bin/env bash
set -euo pipefail

CURRENT_WALL="$HOME/.local/share/wallpapers/current"

daemon=""
client=""
if command -v awww-daemon >/dev/null 2>&1 && command -v awww >/dev/null 2>&1; then
    daemon="awww-daemon"
    client="awww"
elif command -v swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
    daemon="swww-daemon"
    client="swww"
else
    exit 0
fi

restarted=0
if ! pgrep -x "$daemon" >/dev/null 2>&1; then
    "$daemon" >/dev/null 2>&1 &
    sleep 0.5
    restarted=1
fi

if [[ -f "$CURRENT_WALL" ]]; then
    if [[ "$client" == "swww" ]]; then
        swww img "$CURRENT_WALL" \
            --transition-type "${WALL_TRANSITION_TYPE:-wipe}" \
            --transition-angle "${WALL_TRANSITION_ANGLE:-45}" \
            --transition-step "${WALL_TRANSITION_STEP:-90}" \
            --transition-fps "${WALL_TRANSITION_FPS:-120}" >/dev/null 2>&1 || true
    elif [[ "$client" == "awww" ]]; then
        awww img "$CURRENT_WALL" \
            --transition-type "${WALL_TRANSITION_TYPE:-wave}" \
            --transition-angle "${WALL_TRANSITION_ANGLE:-45}" \
            --transition-wave "${AWWW_TRANSITION_WAVE:-40,30}" \
            --transition-step "${WALL_TRANSITION_STEP:-10}" \
            --transition-fps "${WALL_TRANSITION_FPS:-120}" >/dev/null 2>&1 || true
    fi
fi

# Video vrstva: pokud je aktivní video tapeta a mpvpaper neběží (po restartu sezení
# nebo když spadl), nahodit ho zpátky. 'ensure' běžící instanci nechá být, aby
# healthcheck nerestartoval video při každém tiknutí timeru.
if [[ -x "$HOME/.local/bin/wallpaper-video-ctl.sh" ]]; then
    # Po restartu daemonu ale sync: mpvpaper sdílí s awww vrstvu background
    # a niri kreslí později namapovaný povrch navrch — nový awww by jinak
    # video překryl. sync mpvpaper restartuje, takže bude zase nahoře.
    if [[ "$restarted" == 1 ]]; then
        "$HOME/.local/bin/wallpaper-video-ctl.sh" sync >/dev/null 2>&1 || true
    else
        "$HOME/.local/bin/wallpaper-video-ctl.sh" ensure >/dev/null 2>&1 || true
    fi
fi

