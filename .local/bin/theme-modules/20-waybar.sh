#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/waybar"
cat > "$HOME/.config/waybar/colors.css" <<EOF
@define-color background ${background};
@define-color foreground ${foreground};
@define-color color0 ${color0};
@define-color color1 ${accent_urgent};
@define-color color2 ${color2};
@define-color color3 ${color3};
@define-color color4 ${accent_blue};
@define-color color5 ${accent};
@define-color color6 ${accent_soft};
@define-color color7 ${color7};
@define-color color8 ${color8};
@define-color accent ${accent};
@define-color accent_soft ${accent_soft};
@define-color accent_blue ${accent_blue};
EOF
