#!/usr/bin/env bash
set -euo pipefail

if ! pgrep -x eww >/dev/null 2>&1; then
  eww daemon >/dev/null 2>&1 &
  sleep 0.4
fi

if eww active-windows | grep -q ": niri_quick$"; then
  eww close niri_quick
fi
eww open --toggle start_menu
