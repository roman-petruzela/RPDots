#!/usr/bin/env bash
set -euo pipefail

command -v spicetify >/dev/null 2>&1 || exit 0
[[ -d "$HOME/.config/spicetify" ]] || exit 0

# matugen already wrote color.ini and user.css via templates.
# Ensure the right theme/scheme is selected, then apply.
spicetify config current_theme PywalDynamic 2>/dev/null || true
spicetify config color_scheme wal 2>/dev/null || true

# Remember where Spotify sits: `spicetify apply` restarts it, and the fresh
# window would otherwise open on whatever workspace happens to be active.
# The app-id really is "Spotify" with a capital S, hence the case-insensitive test.
SPOTIFY_SEL='.[] | select(.app_id | test("^spotify$"; "i"))'
TARGET_OUTPUT=""
TARGET_IDX=""
OLD_WID=""

# `spicetify apply` restarts Spotify — and starts it even when it was not
# running, which is why every wallpaper change used to pop Spotify open. Only
# take the restarting path when it is already running; otherwise patch the files
# in place with --no-restart and let the next manual launch pick the theme up.
if ! pgrep -x spotify >/dev/null 2>&1; then
    spicetify -q -n apply 2>/dev/null || spicetify -q -n backup apply 2>/dev/null || true
    exit 0
fi

if command -v niri >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    # Id of the window that is about to be killed. `spicetify apply` restarts
    # Spotify asynchronously: measured here, the command returns ~0.7 s in, the
    # old window lives on for another ~2.6 s, and the replacement appears ~2.9 s
    # after the return. Polling for "a Spotify window" therefore always found the
    # *old* one, moved it to where it already was and gave up — the new window
    # then opened on whatever workspace happened to be focused. Waiting for an id
    # different from this one is what makes the restore fire on the right window.
    OLD_WID="$(niri msg --json windows 2>/dev/null \
        | jq -r "$SPOTIFY_SEL | .id" 2>/dev/null | head -n1 || true)"
    ws_id="$(niri msg --json windows 2>/dev/null \
        | jq -r "$SPOTIFY_SEL | .workspace_id" 2>/dev/null | head -n1 || true)"
    if [[ -n "$ws_id" && "$ws_id" != "null" ]]; then
        # Record index + output, not the workspace id: move-window-to-workspace
        # takes an index or a name, and would read a raw id as an index.
        # Caveat: niri's indices are dynamic. If Spotify was the only window on
        # its workspace, that workspace disappears while Spotify is down and the
        # ones after it shift up, so the index restores the slot rather than the
        # exact workspace. A declared named workspace would be exact.
        read -r TARGET_IDX TARGET_OUTPUT <<<"$(niri msg --json workspaces 2>/dev/null \
            | jq -r --argjson id "$ws_id" \
                '.[] | select(.id == $id) | "\(.idx) \(.output)"' 2>/dev/null || true)" || true
    fi
fi

spicetify apply -q 2>/dev/null || spicetify backup apply -q 2>/dev/null || true

# Put Spotify back where it was and resume playback.
if [[ -n "$TARGET_IDX" && -n "$TARGET_OUTPUT" ]]; then
    (
        # ~3 s is the measured turnaround; 15 s leaves room for a slow start.
        for _ in $(seq 1 75); do
            wid="$(niri msg --json windows 2>/dev/null \
                | jq -r "$SPOTIFY_SEL | .id" 2>/dev/null | head -n1 || true)"
            if [[ -n "$wid" && "$wid" != "null" && "$wid" != "$OLD_WID" ]]; then
                # --id / --window-id matter: without them these actions move the
                # *focused* window, i.e. whatever the user is working in.
                # Workspace indices are per-output and resolve against the moved
                # window's own output, so the monitor has to be set first.
                # --focus false leaves the user where they are.
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
