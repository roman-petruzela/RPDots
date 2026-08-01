#!/usr/bin/env bash
set -euo pipefail
# priority: 62

# matugen already wrote RPRice.conf to qt5ct/qt6ct colors directories.
# Here we point the qt*ct configs at that file and keep Kvantum theme consistent.

qt5_dir="${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct"
qt6_dir="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct"
kv_dir="${XDG_CONFIG_HOME:-$HOME/.config}/Kvantum"

_set_color_scheme() {
    local conf="$1" dir="$2"
    [[ -f "$conf" ]] || return 0
    if grep -q '^color_scheme_path=' "$conf"; then
        sed -i "s#^color_scheme_path=.*#color_scheme_path=$dir/colors/RPRice.conf#" "$conf"
    else
        printf '\ncolor_scheme_path=%s/colors/RPRice.conf\n' "$dir" >> "$conf"
    fi
}

_set_color_scheme "$qt5_dir/qt5ct.conf" "$qt5_dir"
_set_color_scheme "$qt6_dir/qt6ct.conf" "$qt6_dir"

# Kvantum: ensure kvantum.kvconfig exists and points to an installed dark theme
mkdir -p "$kv_dir"
kv_cfg="$kv_dir/kvantum.kvconfig"
# Prefer niri-rice if the user has set it up; otherwise fall back to KvGnomeDark
desired_theme="niri-rice"
[[ -d "$kv_dir/niri-rice" ]] || desired_theme="KvGnomeDark"

if [[ -f "$kv_cfg" ]]; then
    if grep -q '^theme=' "$kv_cfg"; then
        sed -i "s/^theme=.*/theme=$desired_theme/" "$kv_cfg"
    else
        printf '\ntheme=%s\n' "$desired_theme" >> "$kv_cfg"
    fi
else
    printf '[General]\ntheme=%s\n' "$desired_theme" > "$kv_cfg"
fi
