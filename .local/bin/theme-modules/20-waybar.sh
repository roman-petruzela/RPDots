#!/usr/bin/env bash
# WAYBAR-COLORS: matugen generates waybar/colors.css directly — this module only reloads
set -euo pipefail

# Reload waybar with SIGUSR2 (CSS hot-reload, no restart)
if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR2 waybar 2>/dev/null || true
fi
