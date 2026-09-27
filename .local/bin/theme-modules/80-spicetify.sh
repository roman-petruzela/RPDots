#!/usr/bin/env bash
set -euo pipefail

command -v spicetify >/dev/null 2>&1 || exit 0
[[ -d "$HOME/.config/spicetify" ]] || exit 0

spicetify config current_theme PywalDynamic 2>/dev/null || true
spicetify config color_scheme wal 2>/dev/null || true

warn_mismatch() {
    grep -qi "mismatched" <<<"$1" || return 0
    local flag="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/spicetify-warned"
    [[ "$(cat "$flag" 2>/dev/null)" == "$(date +%F)" ]] && return 0
    date +%F >"$flag"
    notify-send -a Spicetify "Spotify colours are not updating" \
        "Spotify was updated. Reinstall it (paru -S spotify), then run: spicetify backup apply" 2>/dev/null || true
}

SPOTIFY_SEL='.[] | select(.app_id | test("^spotify$"; "i"))'
TARGET_OUTPUT=""
TARGET_IDX=""
OLD_WID=""

if ! pgrep -x spotify >/dev/null 2>&1; then
    out="$(spicetify -q -n apply 2>&1)" || out+="$(spicetify -q -n backup apply 2>&1)" || true
    warn_mismatch "$out"
    exit 0
fi

if command -v niri >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    OLD_WID="$(niri msg --json windows 2>/dev/null \
        | jq -r "$SPOTIFY_SEL | .id" 2>/dev/null | head -n1 || true)"
    ws_id="$(niri msg --json windows 2>/dev/null \
        | jq -r "$SPOTIFY_SEL | .workspace_id" 2>/dev/null | head -n1 || true)"
    if [[ -n "$ws_id" && "$ws_id" != "null" ]]; then
        read -r TARGET_IDX TARGET_OUTPUT <<<"$(niri msg --json workspaces 2>/dev/null \
            | jq -r --argjson id "$ws_id" \
                '.[] | select(.id == $id) | "\(.idx) \(.output)"' 2>/dev/null || true)" || true
    fi
fi

out="$(spicetify apply -q 2>&1)" || out+="$(spicetify backup apply -q 2>&1)" || true
warn_mismatch "$out"

if [[ -n "$TARGET_IDX" && -n "$TARGET_OUTPUT" ]]; then
    (
        for _ in $(seq 1 75); do
            wid="$(niri msg --json windows 2>/dev/null \
                | jq -r "$SPOTIFY_SEL | .id" 2>/dev/null | head -n1 || true)"
            if [[ -n "$wid" && "$wid" != "null" && "$wid" != "$OLD_WID" ]]; then
                niri msg action move-window-to-monitor \
                    --id "$wid" "$TARGET_OUTPUT" 2>/dev/null || true
                sleep 0.3
                niri msg action move-window-to-workspace \
                    --window-id "$wid" --focus false "$TARGET_IDX" 2>/dev/null || true
                sleep 0.5
                playerctl --player=spotify play 2>/dev/null || true
                break
            fi
            sleep 0.2
        done
    ) &
fi
