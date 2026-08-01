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

# Apply to every running kitty instance via its per-pid socket
# (requires listen_on unix:/tmp/kitty-{kitty_pid} in kitty.conf)
applied=0
for sock in /tmp/kitty-[0-9]*; do
    [[ -S "$sock" ]] || continue
    kitty @ --to="unix:$sock" set-colors -a "$KITTY_THEME_FILE" 2>/dev/null && applied=1 || true
done

# Fallback: try without explicit socket (works inside a kitty terminal)
if [[ "$applied" -eq 0 ]]; then
    kitty @ set-colors -a "$KITTY_THEME_FILE" 2>/dev/null || true
fi
