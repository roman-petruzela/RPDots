#!/usr/bin/env bash
set -euo pipefail

# Make running GTK3 apps (Thunar above all) pick up the freshly generated colors
# without restarting them.
#
# GTK3 reads ~/.config/gtk-3.0/gtk.css exactly once, at startup — editing it does
# nothing for a running app. A *named theme* however is re-read from disk every
# time the theme name changes, so bouncing the name off RPRice and back reloads
# ~/.local/share/themes/RPRice/gtk-3.0/gtk{,-dark}.css that matugen just wrote.
#
# Wayland clients take the theme from GSettings, XWayland ones from XSETTINGS,
# so both channels get bounced.

THEME="${RICE_GTK_THEME:-RPRice}"
FALLBACK="${RICE_GTK_THEME_FALLBACK:-Adwaita}"

# Nothing to reload until matugen has generated the theme at least once.
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
