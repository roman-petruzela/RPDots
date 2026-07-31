#!/usr/bin/env bash
set -euo pipefail

KITTY_THEME_FILE="$HOME/.config/kitty/current-theme.conf"
KITTY_MAIN_CONF="$HOME/.config/kitty/kitty.conf"

if [[ -f "$HOME/.cache/wal/colors-kitty.conf" ]]; then
  mkdir -p "$HOME/.config/kitty"
  cp -f "$HOME/.cache/wal/colors-kitty.conf" "$KITTY_THEME_FILE"
  if [[ -f "$KITTY_MAIN_CONF" ]] && ! grep -Fq "include ~/.config/kitty/current-theme.conf" "$KITTY_MAIN_CONF"; then
    printf '\ninclude ~/.config/kitty/current-theme.conf\n' >> "$KITTY_MAIN_CONF"
  fi
  kitty @ set-colors -a "$KITTY_THEME_FILE" >/dev/null 2>&1 || true
fi
