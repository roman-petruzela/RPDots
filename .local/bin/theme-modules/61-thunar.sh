#!/usr/bin/env bash
set -euo pipefail

# Thunar is a GTK3 app, so its colors come from the RPRice GTK3 theme that
# matugen generates into ~/.local/share/themes/RPRice/gtk-3.0/. This module
# handles what a stylesheet cannot: selecting that theme, picking the dark or
# light variant from wallpaper luminance, and forcing running apps to re-read it.

GTK_THEME_NAME="${RICE_GTK_THEME:-RPRice}"
THEME_DIR="$HOME/.local/share/themes/$GTK_THEME_NAME/gtk-3.0"

# Keep GTK dark/light preference synced with wallpaper luminance so Thunar tracks system mood.
bg="${background#\#}"
r=$((16#${bg:0:2}))
g=$((16#${bg:2:2}))
b=$((16#${bg:4:2}))
lum=$(( (2126 * r + 7152 * g + 722 * b) / 10000 ))
prefer_dark=1
(( lum >= 140 )) && prefer_dark=0

set_ini_key() {
  local file="$1" key="$2" value="$3"
  [[ -f "$file" ]] || return 0
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
  set_ini_key "$f" gtk-application-prefer-dark-theme "$prefer_dark"
done

# Only GTK3 gets the generated theme; GTK4/libadwaita is coloured by gtk-4.0/gtk.css.
if [[ -f "$THEME_DIR/gtk.css" ]]; then
  set_ini_key "$HOME/.config/gtk-3.0/settings.ini" gtk-theme-name "$GTK_THEME_NAME"
fi

# Wayland GTK apps read theme and color scheme from GSettings.
if command -v gsettings >/dev/null 2>&1; then
  if (( prefer_dark )); then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' >/dev/null 2>&1 || true
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' >/dev/null 2>&1 || true
  fi
fi

# XSETTINGS for XWayland GTK apps — only takes effect if xfsettingsd is running.
if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Net/CursorThemeName -s "Bibata-Modern-Ice" >/dev/null 2>&1 || true
  xfconf-query -c xsettings -p /Gtk/ApplicationPreferDarkTheme -s "$prefer_dark" >/dev/null 2>&1 || true
fi

# Make already-open Thunar windows pick up the new colors.
if [[ -x "$HOME/.local/bin/gtk-live-reload.sh" ]]; then
  "$HOME/.local/bin/gtk-live-reload.sh" >/dev/null 2>&1 || true
fi
