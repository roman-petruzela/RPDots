#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
CURRENT_VIDEO="$STATE_DIR/current-video"

VIDEO_INHIBIT="$STATE_DIR/video-inhibit"

LAYER="${WALL_VIDEO_LAYER:-background}"

MPV_OPTS="${WALL_VIDEO_MPV_OPTS:-no-audio loop-file=inf hwdec=auto-safe profile=fast video-sync=display-resample panscan=1.0}"

have_mpvpaper() { command -v mpvpaper >/dev/null 2>&1; }

SHOWN_FILE="$STATE_DIR/wallpaper-shown"
mark_shown() { date +%s%N >"$SHOWN_FILE" 2>/dev/null || true; }

wait_for_transition() {
    local pid deadline prev cur
    if [[ -n "${WALL_VIDEO_START_DELAY:-}" ]]; then
        sleep "$WALL_VIDEO_START_DELAY"
        return 0
    fi
    pid="$(pgrep -x awww-daemon 2>/dev/null | head -1 || true)"
    [[ -n "$pid" ]] || { sleep 0.5; return 0; }

    prev="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo 0)"
    deadline=$((SECONDS + ${WALL_VIDEO_START_TIMEOUT:-6}))
    while ((SECONDS < deadline)); do
        sleep 0.25
        cur="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo "$prev")"
        [[ "$cur" == "$prev" ]] && return 0
        prev="$cur"
    done
}

stop_video() {
    pgrep -x mpvpaper >/dev/null 2>&1 || return 0
    pkill -x mpvpaper >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        sleep 0.05
        pgrep -x mpvpaper >/dev/null 2>&1 || return 0
    done
    pkill -KILL -x mpvpaper >/dev/null 2>&1 || true
    sleep 0.2
}

start_video() {
    local video="$1"
    have_mpvpaper || { mark_shown; return 0; }
    [[ -f "$video" ]] || { mark_shown; return 0; }
    [[ -f "$VIDEO_INHIBIT" ]] && { stop_video; mark_shown; return 0; }

    stop_video
    mark_shown
    sleep 0.2
    wait_for_transition

    local still=""
    [[ -f "$CURRENT_VIDEO" ]] && still="$(cat "$CURRENT_VIDEO" 2>/dev/null || true)"
    if [[ "$still" != "$video" ]]; then
        stop_video
        return 0
    fi

    mpvpaper -f -p -l "$LAYER" -o "$MPV_OPTS" '*' "$video" >/dev/null 2>&1 || true
}

sync_video() {
    [[ -f "$VIDEO_INHIBIT" ]] && { stop_video; mark_shown; return 0; }
    if [[ -f "$CURRENT_VIDEO" ]]; then
        local video
        video="$(cat "$CURRENT_VIDEO" 2>/dev/null || true)"
        if [[ -n "$video" && -f "$video" ]]; then
            start_video "$video"
            return 0
        fi
        rm -f "$CURRENT_VIDEO"
    fi
    stop_video
    mark_shown
}

ensure_video() {
    [[ -f "$VIDEO_INHIBIT" ]] && { stop_video; return 0; }
    [[ -f "$CURRENT_VIDEO" ]] || { stop_video; return 0; }
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        return 0
    fi
    sync_video
}

inhibit_video() {
    mkdir -p "$STATE_DIR"
    : > "$VIDEO_INHIBIT"
    stop_video
}

uninhibit_video() {
    rm -f "$VIDEO_INHIBIT"
    sync_video
}

case "${1:-sync}" in
    sync)      sync_video ;;
    ensure)    ensure_video ;;
    start)     [[ -n "${2:-}" ]] && start_video "$2" ;;
    stop)      stop_video ;;
    inhibit)   inhibit_video ;;
    uninhibit) uninhibit_video ;;
    *)
        echo "Použití: $(basename "$0") {sync|ensure|start <video>|stop|inhibit|uninhibit}" >&2
        exit 1
        ;;
esac
