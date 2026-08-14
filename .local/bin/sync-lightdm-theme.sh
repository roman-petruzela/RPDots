#!/usr/bin/env bash
# Kopíruje aktuální RPRice GTK3 téma + tapetu do systémových cest, které vidí
# uživatel lightdm (/home/roman je 700), a nastaví je v lightdm-gtk-greeter.conf.
# Spouštět s: sudo ~/.local/bin/sync-lightdm-theme.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Spusť s sudo: sudo $0" >&2
    exit 1
fi

USER_HOME="/home/${SUDO_USER:-roman}"
SRC_THEME="$USER_HOME/.local/share/themes/RPRice"
SRC_WALLPAPER="$USER_HOME/.local/share/wallpapers/current"
DST_THEME="/usr/share/themes/RPRice"
DST_WALLPAPER="/usr/share/backgrounds/rprice-current.jpg"
GREETER_CONF="/etc/lightdm/lightdm-gtk-greeter.conf"

if [[ ! -d "$SRC_THEME" ]]; then
    echo "Nenalezeno: $SRC_THEME (matugen ještě negeneroval GTK3 téma?)" >&2
    exit 1
fi
if [[ ! -f "$SRC_WALLPAPER" ]]; then
    echo "Nenalezeno: $SRC_WALLPAPER" >&2
    exit 1
fi

mkdir -p "$DST_THEME" /usr/share/backgrounds
rsync -a --delete "$SRC_THEME"/ "$DST_THEME"/
cp "$SRC_WALLPAPER" "$DST_WALLPAPER"
chmod -R a+rX "$DST_THEME"
chmod a+r "$DST_WALLPAPER"

set_key() {
    local key="$1" value="$2"
    if grep -qE "^${key}=" "$GREETER_CONF"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$GREETER_CONF"
    elif grep -qE "^#${key}=" "$GREETER_CONF"; then
        sed -i "s|^#${key}=.*|${key}=${value}|" "$GREETER_CONF"
    else
        sed -i "/^\[greeter\]/a ${key}=${value}" "$GREETER_CONF"
    fi
}

set_key "theme-name" "RPRice"
set_key "icon-theme-name" "Papirus-Dark"
set_key "cursor-theme-name" "Bibata-Modern-Ice"
set_key "font-name" "Adwaita Sans 11"
set_key "background" "$DST_WALLPAPER"

echo "Hotovo. Restartuj lightdm (sudo systemctl restart lightdm) nebo se odhlas pro náhled."
