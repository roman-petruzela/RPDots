#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
SESSION_ENV_FILE="$STATE_DIR/systemd-session.env"
COLORS_FILE="$HOME/.config/waybar/colors.css"
CONFIG_FILE="$HOME/.config/waybar/config.jsonc"
HASH_FILE="$STATE_DIR/waybar-colors.sha"
CONFIG_HASH_FILE="$STATE_DIR/waybar-config.sha"

mkdir -p "$STATE_DIR"

if [[ "$(cat "$HOME/.config/niri-rice/bar" 2>/dev/null)" == quickshell ]]; then
  systemctl --user stop waybar.service 2>/dev/null || true
  exit 0
fi

if [[ -f "$SESSION_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$SESSION_ENV_FILE"
  set +a
fi

reload_if_config_changed() {
  [[ -f "$CONFIG_FILE" ]] || return 0
  local current_hash last_hash
  current_hash="$(sha256sum "$CONFIG_FILE" | awk '{print $1}')"
  last_hash="$(cat "$CONFIG_HASH_FILE" 2>/dev/null || true)"
  if [[ -n "$current_hash" && "$current_hash" != "$last_hash" ]]; then
    systemctl --user restart waybar.service
    printf '%s\n' "$current_hash" > "$CONFIG_HASH_FILE"
    return 0
  fi
}

reload_if_colors_changed() {
  [[ -f "$COLORS_FILE" ]] || return 0
  local current_hash last_hash
  current_hash="$(sha256sum "$COLORS_FILE" | awk '{print $1}')"
  last_hash="$(cat "$HASH_FILE" 2>/dev/null || true)"
  if [[ -n "$current_hash" && "$current_hash" != "$last_hash" ]]; then
    pkill -x -USR2 waybar 2>/dev/null || true
    printf '%s\n' "$current_hash" > "$HASH_FILE"
  fi
}

if pgrep -x waybar >/dev/null 2>&1; then
  reload_if_config_changed
  reload_if_colors_changed
  exit 0
fi

systemctl --user start waybar.service
if [[ -f "$COLORS_FILE" ]]; then
  sha256sum "$COLORS_FILE" | awk '{print $1}' > "$HASH_FILE"
fi
if [[ -f "$CONFIG_FILE" ]]; then
  sha256sum "$CONFIG_FILE" | awk '{print $1}' > "$CONFIG_HASH_FILE"
fi
