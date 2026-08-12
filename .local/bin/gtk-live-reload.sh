#!/usr/bin/env bash
set -euo pipefail

THEME="${RICE_GTK_THEME:-RPRice}"
FALLBACK="${RICE_GTK_THEME_FALLBACK:-Adwaita}"

[[ -f "$HOME/.local/share/themes/$THEME/gtk-3.0/gtk.css" ]] || exit 0

bounce_gsettings() {
  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings set org.gnome.desktop.interface gtk-theme "$FALLBACK" 2>/dev/null || return 0
  gsettings set org.gnome.desktop.interface gtk-theme "$THEME" 2>/dev/null || true
}

bounce_xsettings() {
  command -v xfconf-query >/dev/null 2>&1 || return 0
  pgrep -x xfsettingsd >/dev/null 2>&1 || return 0
  xfconf-query -c xsettings -p /Net/ThemeName -s "$FALLBACK" >/dev/null 2>&1 || return 0
  xfconf-query -c xsettings -p /Net/ThemeName -s "$THEME" >/dev/null 2>&1 || true
}

bounce_gsettings
bounce_xsettings
