#!/usr/bin/env bash
set -euo pipefail
# matugen already wrote ~/.config/rofi/pywal-dynamic.rasi via its template.
mkdir -p "$HOME/.config/rofi"

cfg="$HOME/.config/rofi/config.rasi"
if [[ -f "$cfg" ]]; then
    sed -i 's#@theme ".*"#@theme "pywal-dynamic"#' "$cfg"
fi
