#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/fuzzel"
cat > "$HOME/.config/fuzzel/fuzzel.ini" <<EOF
[main]
font=JetBrainsMono Nerd Font:size=12
prompt="  "
lines=12
width=48
horizontal-pad=20
vertical-pad=12
inner-pad=10
layer=overlay
dpi-aware=no

[colors]
background=${background#\#}e6
text=${foreground#\#}ff
prompt=${accent#\#}ff
placeholder=${color8#\#}ff
input=${foreground#\#}ff
match=${accent#\#}ff
selection=${color0#\#}ff
selection-text=${foreground#\#}ff
selection-match=${accent_blue#\#}ff
counter=${color8#\#}ff
border=${accent#\#}ff
EOF
