#!/usr/bin/env bash
set -euo pipefail

# Keep GTK dark/light preference synced with wallpaper luminance so Thunar tracks system mood.
bg="${background#\#}"
r=$((16#${bg:0:2}))
g=$((16#${bg:2:2}))
b=$((16#${bg:4:2}))
lum=$(( (2126 * r + 7152 * g + 722 * b) / 10000 ))
prefer_dark=1
(( lum >= 140 )) && prefer_dark=0

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
  if [[ -f "$f" ]]; then
    if grep -q '^gtk-application-prefer-dark-theme=' "$f"; then
      sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=${prefer_dark}/" "$f"
    else
      printf 'gtk-application-prefer-dark-theme=%s\n' "$prefer_dark" >> "$f"
    fi
  fi
done

if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Net/CursorThemeName -s "Bibata-Modern-Ice" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Gtk/ApplicationPreferDarkTheme -s "$prefer_dark" >/dev/null 2>&1 || true
fi
