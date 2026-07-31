#!/usr/bin/env bash
set -euo pipefail
# priority: 63

template_dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri-rice/templates"
mkdir -p "$template_dir"

create_default_template() {
  local path="$1"
  local content="$2"
  [[ -f "$path" ]] || printf '%s\n' "$content" > "$path"
}

create_default_template "$template_dir/kitty-current-theme.dcol" '$HOME/.config/kitty/current-theme.conf|
foreground   <foreground>
background   <background>
cursor       <foreground>

color0       <color0>
color8       <color8>
color1       <color1>
color9       <color9>
color2       <color2>
color10      <color10>
color3       <color3>
color11      <color11>
color4       <color4>
color12      <color12>
color5       <color5>
color13      <color13>
color6       <color6>
color14      <color14>
color7       <color7>
color15      <color15>'

create_default_template "$template_dir/vesktop-quickcss.dcol" '$HOME/.config/vesktop/settings/quickCss.css|
:root {
  --wal-accent: <accent>;
  --wal-accent-alt: <accent_blue>;
  --wal-bg: <background>;
  --wal-fg: <foreground>;
}'

create_default_template "$template_dir/spicetify-color.dcol" '$HOME/.config/spicetify/Themes/PywalDynamic/color.ini|
[wal]
text               = <color6_raw>
subtext            = <color7_raw>
main               = <background_raw>
main-elevated      = <color0_raw>
sidebar            = <color0_raw>
player             = <background_raw>
card               = <color0_raw>
shadow             = 000000
selected-row       = <color8_raw>
button             = <accent_raw>
button-active      = <accent_blue_raw>
button-disabled    = <color8_raw>
tab-active         = <accent_soft_raw>
notification       = <accent_raw>
notification-error = <accent_urgent_raw>
misc               = <accent_raw>'

render_template() {
  local template="$1"
  local header target command tmp
  header="$(head -n1 "$template")"
  target="${header%%|*}"
  command="${header#*|}"
  [[ "$command" == "$header" ]] && command=""
  eval "target=\"$target\""
  mkdir -p "$(dirname "$target")"

  tmp="$(mktemp)"
  tail -n +2 "$template" > "$tmp"

  sed -i \
    -e "s|<background>|${background}|g" \
    -e "s|<foreground>|${foreground}|g" \
    -e "s|<accent>|${accent}|g" \
    -e "s|<accent_soft>|${accent_soft}|g" \
    -e "s|<accent_blue>|${accent_blue}|g" \
    -e "s|<accent_urgent>|${accent_urgent}|g" \
    -e "s|<background_raw>|${background#\#}|g" \
    -e "s|<foreground_raw>|${foreground#\#}|g" \
    -e "s|<accent_raw>|${accent#\#}|g" \
    -e "s|<accent_soft_raw>|${accent_soft#\#}|g" \
    -e "s|<accent_blue_raw>|${accent_blue#\#}|g" \
    -e "s|<accent_urgent_raw>|${accent_urgent#\#}|g" \
    -e "s|<color0>|${color0}|g" \
    -e "s|<color1>|${color1}|g" \
    -e "s|<color2>|${color2}|g" \
    -e "s|<color3>|${color3}|g" \
    -e "s|<color4>|${color4}|g" \
    -e "s|<color5>|${color5}|g" \
    -e "s|<color6>|${color6}|g" \
    -e "s|<color7>|${color7}|g" \
    -e "s|<color8>|${color8}|g" \
    -e "s|<color9>|${color9}|g" \
    -e "s|<color10>|${color10}|g" \
    -e "s|<color11>|${color11}|g" \
    -e "s|<color12>|${color12}|g" \
    -e "s|<color13>|${color13}|g" \
    -e "s|<color14>|${color14}|g" \
    -e "s|<color15>|${color15}|g" \
    -e "s|<color0_raw>|${color0#\#}|g" \
    -e "s|<color1_raw>|${color1#\#}|g" \
    -e "s|<color2_raw>|${color2#\#}|g" \
    -e "s|<color3_raw>|${color3#\#}|g" \
    -e "s|<color4_raw>|${color4#\#}|g" \
    -e "s|<color5_raw>|${color5#\#}|g" \
    -e "s|<color6_raw>|${color6#\#}|g" \
    -e "s|<color7_raw>|${color7#\#}|g" \
    -e "s|<color8_raw>|${color8#\#}|g" \
    -e "s|<color9_raw>|${color9#\#}|g" \
    -e "s|<color10_raw>|${color10#\#}|g" \
    -e "s|<color11_raw>|${color11#\#}|g" \
    -e "s|<color12_raw>|${color12#\#}|g" \
    -e "s|<color13_raw>|${color13#\#}|g" \
    -e "s|<color14_raw>|${color14#\#}|g" \
    -e "s|<color15_raw>|${color15#\#}|g" \
    "$tmp"

  mv "$tmp" "$target"
  if [[ -n "$command" ]]; then
    bash -lc "$command"
  fi
  printf '%s\n' "$target"
}

shopt -s nullglob
kitty_theme="$HOME/.config/kitty/current-theme.conf"
kitty_theme_updated=0
for tpl in "$template_dir"/*.dcol; do
  target="$(render_template "$tpl")"
  if [[ "$target" == "$kitty_theme" ]]; then
    kitty_theme_updated=1
  fi
done

if [[ "$kitty_theme_updated" -eq 1 ]] && command -v kitty >/dev/null 2>&1; then
  kitty @ set-colors -a "$kitty_theme" >/dev/null 2>&1 || true
fi
