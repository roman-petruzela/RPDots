#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
PID_DIR="$STATE_DIR/pids"
PID_FILE="$PID_DIR/waybar.pid"
SESSION_ENV_FILE="$STATE_DIR/systemd-session.env"
COLORS_FILE="$HOME/.config/waybar/colors.css"
CONFIG_FILE="$HOME/.config/waybar/config.jsonc"
HASH_FILE="$STATE_DIR/waybar-colors.sha"
CONFIG_HASH_FILE="$STATE_DIR/waybar-config.sha"

mkdir -p "$PID_DIR"

if [[ -f "$SESSION_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$SESSION_ENV_FILE"
  set +a
fi

running=0
mapfile -t pids < <(pgrep -x waybar 2>/dev/null || true)
if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    running=1
    pids=("$pid")
  fi
fi
if [[ "$running" -eq 0 && ${#pids[@]} -gt 0 ]]; then
  running=1
  echo "${pids[0]}" > "$PID_FILE"
fi

reload_if_colors_changed() {
  [[ -f "$COLORS_FILE" ]] || return 0
  local current_hash last_hash
  current_hash="$(sha256sum "$COLORS_FILE" | awk '{print $1}')"
  last_hash="$(cat "$HASH_FILE" 2>/dev/null || true)"
  if [[ -n "$current_hash" && "$current_hash" != "$last_hash" ]]; then
    for pid in "${pids[@]}"; do
      kill -USR2 "$pid" 2>/dev/null || true
    done
    printf '%s\n' "$current_hash" > "$HASH_FILE"
  fi
}

reload_if_config_changed() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  local current_hash last_hash
  current_hash="$(sha256sum "$CONFIG_FILE" | awk '{print $1}')"
  last_hash="$(cat "$CONFIG_HASH_FILE" 2>/dev/null || true)"
  if [[ -n "$current_hash" && "$current_hash" != "$last_hash" ]]; then
    for pid in "${pids[@]}"; do
      kill -TERM "$pid" 2>/dev/null || true
    done
    printf '%s\n' "$current_hash" > "$CONFIG_HASH_FILE"
    waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    return 0
  fi
}

if [[ "$running" -eq 1 ]]; then
  reload_if_config_changed
  reload_if_colors_changed
  exit 0
fi

waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
echo $! > "$PID_FILE"
if [[ -f "$COLORS_FILE" ]]; then
  sha256sum "$COLORS_FILE" | awk '{print $1}' > "$HASH_FILE"
fi
if [[ -f "$CONFIG_FILE" ]]; then
  sha256sum "$CONFIG_FILE" | awk '{print $1}' > "$CONFIG_HASH_FILE"
fi
