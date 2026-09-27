#!/usr/bin/env bash
set -euo pipefail

WINDOW="dashboard"

if ! pgrep -x eww >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1 &
    sleep 0.5
fi

if eww active-windows | grep -q ": start_menu$"; then
    eww close start_menu
fi
if eww active-windows | grep -q ": niri_quick$"; then
    eww close niri_quick
fi

eww open --toggle "$WINDOW"
