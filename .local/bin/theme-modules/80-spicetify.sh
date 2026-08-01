#!/usr/bin/env bash
set -euo pipefail

command -v spicetify >/dev/null 2>&1 || exit 0
[[ -d "$HOME/.config/spicetify" ]] || exit 0

# matugen already wrote color.ini and user.css via templates.
# Ensure the right theme/scheme is selected, then apply.
spicetify config current_theme PywalDynamic 2>/dev/null || true
spicetify config color_scheme wal 2>/dev/null || true

# Remember which workspace Spotify is on so we can return it there after restart
TARGET_WORKSPACE=""
if command -v niri >/dev/null 2>&1 && pgrep -x spotify >/dev/null 2>&1; then
    TARGET_WORKSPACE=$(niri msg --json windows \
        | jq -r '.[] | select(.app_id=="spotify") | .workspace_id' 2>/dev/null || true)
fi

spicetify apply -q 2>/dev/null || spicetify backup apply -q 2>/dev/null || true

# Move Spotify back to its workspace and resume playback
if [[ -n "$TARGET_WORKSPACE" ]]; then
    (
        for i in $(seq 1 40); do
            if niri msg --json windows \
                | jq -e '.[] | select(.app_id=="spotify")' >/dev/null 2>&1; then
                niri msg action move-window-to-workspace "$TARGET_WORKSPACE" 2>/dev/null || true
                sleep 0.5
                playerctl --player=spotify play 2>/dev/null || true
                break
            fi
            sleep 0.2
        done
    ) &
fi
