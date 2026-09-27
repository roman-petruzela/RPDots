#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
PID_DIR="$STATE_DIR/pids"
LOG_FILE="$STATE_DIR/startup.log"
SESSION_ENV_FILE="$STATE_DIR/systemd-session.env"
mkdir -p "$PID_DIR"

log() {
  printf '[%s] %s\n' "$(date +'%F %T')" "$*" >> "$LOG_FILE"
}

start_user_unit() {
  local unit="$1"
  if ! command -v systemctl >/dev/null 2>&1; then
    return 1
  fi
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user start "$unit" >/dev/null 2>&1 || return 1
  return 0
}

write_session_env() {
  cat > "$SESSION_ENV_FILE" <<EOF
WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}
DISPLAY=${DISPLAY:-}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-}
DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-}
XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-wayland}
XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-niri}
EOF
}

ensure_pidfile_running() {
  local pidfile="$1"
  local proc_name="$2"
  shift 2

  if [[ -f "$pidfile" ]]; then
    local pid
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi

  local existing_pid
  existing_pid="$(pgrep -x "$proc_name" | head -n 1 || true)"
  if [[ -n "$existing_pid" ]]; then
    echo "$existing_pid" > "$pidfile"
    return 0
  fi

  "$@" >/dev/null 2>&1 &
  echo $! > "$pidfile"
}

start_waybar_with_retry() {
  local pidfile="$PID_DIR/waybar.pid"
  local attempt pid

  for attempt in {1..8}; do
    "$HOME/.local/bin/waybar-watchdog.sh" >/dev/null 2>&1 || true
    pid="$(cat "$pidfile" 2>/dev/null || true)"

    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      sleep 0.6
      if kill -0 "$pid" 2>/dev/null; then
        kill -USR2 "$pid" 2>/dev/null || true
        log "waybar running pid=$pid attempt=$attempt"
        return 0
      fi
    fi

    rm -f "$pidfile"
    sleep 1
  done

  log "waybar failed to stay alive after retries"
  return 1
}

# Výstupy okna Settings: settings.kdl drží i tap/natural-scroll/numlock (config.kdl
# je nemá, viz rp-settings) a šablona mako includuje ~/.config/mako/rp-settings,
# bez kterého mako config odmítne — proto před tématem. Beze změn nic nepřepíše.
"$HOME/.local/bin/rp-settings" apply || log "rp-settings apply failed"

if ! "$HOME/.local/bin/apply-wallpaper-theme.sh" --no-daemon-restart; then
  log "apply-wallpaper-theme failed, continuing startup with existing theme"
fi

write_session_env
# Panelem může být místo waybaru quickshell (rp-bar) — pak waybar vůbec nezkoušet
[[ "$(cat "$HOME/.config/niri-rice/bar" 2>/dev/null)" == quickshell ]] || start_waybar_with_retry || true

start_user_unit niri-rice-playerctld.service >/dev/null 2>&1 || true
start_user_unit niri-rice-wallpaper-healthcheck.service >/dev/null 2>&1 || true
# quickshell = OSD, dashboard a přepínač zvuku (barem zůstává waybar)
start_user_unit niri-rice-quickshell.service >/dev/null 2>&1 || true
# společná hlasitost všech výstupů
start_user_unit niri-rice-audio-sync.service >/dev/null 2>&1 || true
start_user_unit niri-rice-cliphist.service >/dev/null 2>&1 || true
# niri-rice-waybar.service také zakázán
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user start niri-rice-wallpaper-healthcheck.timer >/dev/null 2>&1 || true
  systemctl --user start niri-rice-waybar.timer >/dev/null 2>&1 || true
fi

ensure_pidfile_running "$PID_DIR/mako.pid" mako mako
if command -v makoctl >/dev/null 2>&1; then
  makoctl reload >/dev/null 2>&1 || true
fi

if command -v nm-applet >/dev/null 2>&1; then
  ensure_pidfile_running "$PID_DIR/nm-applet.pid" nm-applet nm-applet --indicator
fi

if command -v blueman-applet >/dev/null 2>&1; then
  ensure_pidfile_running "$PID_DIR/blueman-applet.pid" blueman-applet blueman-applet
fi

if command -v xwayland-satellite >/dev/null 2>&1; then
  ensure_pidfile_running "$PID_DIR/xwayland-satellite.pid" xwayland-satellite xwayland-satellite
fi

# Config píše až rp-display (Settings → Displays); bez něj kanshi hned spadne
if command -v kanshi >/dev/null 2>&1 && [[ -f "$HOME/.config/kanshi/config" ]]; then
  ensure_pidfile_running "$PID_DIR/kanshi.pid" kanshi kanshi
fi

# VNC server jen na loopbacku, vzdálený přístup je přes SSH tunel (viz ~/.config/wayvnc/config)
if command -v wayvnc >/dev/null 2>&1; then
  ensure_pidfile_running "$PID_DIR/wayvnc.pid" wayvnc wayvnc 127.0.0.1 5900
fi

# QuickShell běží jako systemd unit (viz start_user_unit výše).
# Bar je v shell.qml vypnutý přepínačem useBar — barem je waybar.

# Noční světlo (wlsunset), když je v okně Settings zapnuté a nainstalované
"$HOME/.local/bin/rp-settings" nightlight || log "rp-settings nightlight failed"

# swayidle startuje rp-settings — časy zamknutí/vypnutí obrazovky jsou v okně Settings
if ! pgrep -x swayidle >/dev/null 2>&1; then
  "$HOME/.local/bin/rp-settings" idle || log "rp-settings idle failed"
fi
