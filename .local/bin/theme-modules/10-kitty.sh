#!/usr/bin/env bash
# KITTY: matugen generates current-theme.conf — apply it live to running instances
set -euo pipefail

KITTY_THEME_FILE="$HOME/.config/kitty/current-theme.conf"
KITTY_MAIN_CONF="$HOME/.config/kitty/kitty.conf"

[[ -f "$KITTY_THEME_FILE" ]] || exit 0

# Ensure include line exists in kitty.conf
if [[ -f "$KITTY_MAIN_CONF" ]] && ! grep -Fq "include ~/.config/kitty/current-theme.conf" "$KITTY_MAIN_CONF"; then
    printf '\ninclude ~/.config/kitty/current-theme.conf\n' >> "$KITTY_MAIN_CONF"
fi

# Apply colors live to all running kitty instances
kitty @ --to=unix:/tmp/kitty-remote set-colors -a "$KITTY_THEME_FILE" >/dev/null 2>&1 || \
kitty @ set-colors -a "$KITTY_THEME_FILE" >/dev/null 2>&1 || true
