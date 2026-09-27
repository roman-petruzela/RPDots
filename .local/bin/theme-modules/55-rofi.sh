#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/rofi"

cfg="$HOME/.config/rofi/config.rasi"
if [[ -f "$cfg" ]]; then
    sed -i 's#@theme ".*"#@theme "pywal-dynamic"#' "$cfg"
fi
