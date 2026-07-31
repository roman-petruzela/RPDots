#!/usr/bin/env bash
set -euo pipefail

WINDOW="dashboard"

# Zkontroluje, jestli běží eww daemon. Pokud ne, spustí ho na pozadí.
if ! pgrep -x eww >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1 &
    sleep 0.5 # Malá pauza, aby měl daemon čas nastartovat
fi

if eww active-windows | grep -q ": start_menu$"; then
    eww close start_menu
fi
if eww active-windows | grep -q ": niri_quick$"; then
    eww close niri_quick
fi

# Přepne (otevře/zavře) tvé okno
eww open --toggle "$WINDOW"
