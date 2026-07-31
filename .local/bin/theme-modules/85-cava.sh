#!/usr/bin/env bash
set -euo pipefail

cfg="$HOME/.config/cava/config"
[[ -f "$cfg" ]] || exit 0

sed -i \
  -e "s/^gradient_color_1 = .*/gradient_color_1 = '${accent_blue}'/" \
  -e "s/^gradient_color_2 = .*/gradient_color_2 = '${accent}'/" \
  -e "s/^gradient_color_3 = .*/gradient_color_3 = '${accent_soft}'/" \
  "$cfg"
