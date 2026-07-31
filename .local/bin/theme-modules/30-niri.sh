#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/niri"
cat > "$HOME/.config/niri/theme-colors.kdl" <<EOF
layout {
  background-color "rgba(0, 0, 0, 0.0)"
  focus-ring {
      active-color "${accent}"
      inactive-color "${color8}"
      active-gradient from="${accent_blue}" to="${accent}" angle=45
  }

  tab-indicator {
      active-color "${accent}"
      inactive-color "${color8}"
      urgent-color "${accent_urgent}"
  }
}
EOF
