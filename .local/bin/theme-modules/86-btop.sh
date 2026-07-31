#!/usr/bin/env bash
set -euo pipefail

cfg="$HOME/.config/btop/btop.conf"
[[ -f "$cfg" ]] || exit 0

sed -i \
  -e 's/^color_theme = .*/color_theme = "TTY"/' \
  -e 's/^theme_background = .*/theme_background = false/' \
  "$cfg"
