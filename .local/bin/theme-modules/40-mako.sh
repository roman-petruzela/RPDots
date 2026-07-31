#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/mako"
cat > "$HOME/.config/mako/config" <<EOF
sort=-time
layer=overlay
anchor=top-right
font=JetBrainsMono Nerd Font 11
default-timeout=5000
border-size=2
border-radius=10
padding=12
width=360
height=140
margin=16
background-color=${background}e6
text-color=${foreground}ff
border-color=${accent}ff
progress-color=over ${accent}ff

[urgency=high]
border-color=${accent_urgent}ff
EOF
