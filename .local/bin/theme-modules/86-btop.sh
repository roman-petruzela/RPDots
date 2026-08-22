#!/usr/bin/env bash
set -euo pipefail

cfg="$HOME/.config/btop/btop.conf"
[[ -f "$cfg" ]] || exit 0

# matugen wrote ~/.config/btop/themes/rprice.theme — point btop at it
sed -i \
  -e 's|^color_theme = .*|color_theme = "rprice"|' \
  -e 's/^theme_background = .*/theme_background = false/' \
  "$cfg"
