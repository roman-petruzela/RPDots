#!/usr/bin/env bash
set -euo pipefail

KITTY_THEME_FILE="$HOME/.config/kitty/current-theme.conf"
KITTY_MAIN_CONF="$HOME/.config/kitty/kitty.conf"

[[ -f "$KITTY_THEME_FILE" ]] || exit 0

if [[ -f "$KITTY_MAIN_CONF" ]] && ! grep -Fq "include ~/.config/kitty/current-theme.conf" "$KITTY_MAIN_CONF"; then
    printf '\ninclude ~/.config/kitty/current-theme.conf\n' >> "$KITTY_MAIN_CONF"
fi

for sock in /tmp/kitty-*; do
    [[ -S "$sock" ]] || continue
    kitty @ --to="unix:$sock" set-colors --configured -a "$KITTY_THEME_FILE" 2>/dev/null || true
done
