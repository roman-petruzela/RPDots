#!/usr/bin/env bash
set -euo pipefail
# enabled: 1
# priority: 1

CURRENT_WALL="${HOME}/.local/share/wallpapers/current"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
FAST_MODE="${FAST_MODE:-}"

apply_wallpaper_transition() {
    local wall="$1"
    local client daemon
    
    if command -v swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
        daemon="swww-daemon"
        client="swww"
    elif command -v awww >/dev/null 2>&1; then
        client="awww"
    else
        return 0
    fi
    
    if [[ "$client" == "swww" ]]; then
        local trans angle step fps
        trans="${WALL_TRANSITION_TYPE:-wipe}"
        angle="${WALL_TRANSITION_ANGLE:-45}"
        if [[ "$FAST_MODE" == "yes" ]]; then
            step="${WALL_TRANSITION_STEP_FAST:-160}"
            fps="${WALL_TRANSITION_FPS_FAST:-120}"
        else
            step="${WALL_TRANSITION_STEP:-90}"
            fps="${WALL_TRANSITION_FPS:-120}"
        fi
        swww img "$wall" \
            --transition-type "$trans" \
            --transition-angle "$angle" \
            --transition-step "$step" \
            --transition-fps "$fps" || true
    else
        local help trans angle step fps wave pos args
        help="$(awww img --help 2>/dev/null || true)"
        
        trans="${AWWW_TRANSITION_TYPE:-${WALL_TRANSITION_TYPE:-wave}}"
        angle="${AWWW_TRANSITION_ANGLE:-${WALL_TRANSITION_ANGLE:-45}}"

        if [[ "$FAST_MODE" == "yes" ]]; then
            step="${AWWW_TRANSITION_STEP_FAST:-20}"
            fps="${AWWW_TRANSITION_FPS_FAST:-120}"
        else
            step="${AWWW_TRANSITION_STEP:-10}"
            fps="${AWWW_TRANSITION_FPS:-120}"
        fi
        wave="${AWWW_TRANSITION_WAVE:-40,30}"
        pos="${AWWW_TRANSITION_POS:-0.5,0.5}"
        
        args=(img "$wall")
        if [[ "$help" == *"--transition-type"* ]]; then
            args+=(--transition-type "$trans")
        elif [[ "$help" == *" -t, --transition-type"* ]]; then
            args+=(--transition-type "$trans")
        fi
        [[ "$help" == *"--transition-step"* ]] && args+=(--transition-step "$step")
        [[ "$help" == *"--transition-angle"* ]] && args+=(--transition-angle "$angle")
        [[ "$help" == *"--transition-fps"* ]] && args+=(--transition-fps "$fps")
        [[ "$help" == *"--transition-wave"* ]] && args+=(--transition-wave "$wave")
        [[ "$help" == *"--transition-pos"* ]] && args+=(--transition-pos "$pos")
        
        awww "${args[@]}" >/dev/null 2>&1 || awww img "$wall" >/dev/null 2>&1 || true
    fi
}

[[ "${WALLPAPER_TRANSITION_DONE:-}" == "1" ]] && exit 0

if [[ -f "$CURRENT_WALL" ]]; then
    apply_wallpaper_transition "$CURRENT_WALL"
fi
