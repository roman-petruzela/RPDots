#!/usr/bin/env bash
set -euo pipefail

if ! pgrep -x eww >/dev/null 2>&1; then
  eww daemon >/dev/null 2>&1 &
  sleep 0.4
fi

if eww active-windows | grep -q ": start_menu$"; then
  eww close start_menu
fi
eww open --toggle niri_quick
