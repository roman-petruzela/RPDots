#!/usr/bin/env bash
set -euo pipefail

if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR2 waybar 2>/dev/null || true
fi
