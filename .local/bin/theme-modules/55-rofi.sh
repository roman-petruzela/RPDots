#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/rofi"

cat > "$HOME/.config/rofi/pywal-dynamic.rasi" <<EOF
* {
    bg0: ${background}e8;
    bg1: ${color0}ee;
    fg0: ${foreground};
    cyan: ${accent_blue};
    pink: ${accent};
    border: ${accent}66;
}

window {
    location: center;
    width: 38%;
    border: 2px;
    border-color: @border;
    border-radius: 12px;
    background-color: @bg0;
}

mainbox { spacing: 10px; padding: 14px; }
inputbar { background-color: @bg1; border-radius: 8px; padding: 8px; }
prompt { text-color: @cyan; padding: 0 8px 0 4px; }
entry { text-color: @fg0; }
listview { lines: 10; columns: 1; fixed-height: false; scrollbar: true; background-color: transparent; }
element { padding: 8px; border-radius: 8px; text-color: @fg0; }
element selected { background-color: ${color0}; text-color: @cyan; }
element-icon { size: 1.1em; }
mode-switcher { spacing: 8px; }
button selected { background-color: @pink; text-color: ${background}; }
EOF

if [[ -f "$HOME/.config/rofi/config.rasi" ]]; then
  sed -i 's#@theme ".*"#@theme "pywal-dynamic"#' "$HOME/.config/rofi/config.rasi"
fi
