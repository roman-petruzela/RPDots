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

# Apply to every running kitty instance; --configured updates the "reset" baseline too
for sock in /tmp/kitty-*; do
    [[ -S "$sock" ]] || continue
    kitty @ --to="unix:$sock" set-colors --configured -a "$KITTY_THEME_FILE" 2>/dev/null || true
done
