#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch"
CFG_FILE="$CFG_DIR/config.jsonc"
BASE_IMG="$CFG_DIR/rplogo.png"
LOGO_OUT="$CACHE_DIR/rplogo-small.png"
# Terminal logo only ever displays at --logo-width 16 cells; the source PNG is
# 2000x2000, and sending that much data over the kitty graphics protocol on
# every run silently fails (fastfetch reserves no space for it at all).
LOGO_TARGET_SIZE=256
mkdir -p "$CACHE_DIR"

logo_source="$BASE_IMG"
# fastfetch's own kitty-protocol implementation ("kitty") renders nothing on this
# setup; kitty-icat shells out to kitty's own `kitten icat`, which is the
# reference implementation and far less likely to have protocol edge cases.
logo_type="kitty-icat"

if command -v magick >/dev/null 2>&1 && [[ -f "$BASE_IMG" ]]; then
    if magick "$BASE_IMG" -resize "${LOGO_TARGET_SIZE}x${LOGO_TARGET_SIZE}" -depth 8 "$LOGO_OUT" 2>/dev/null; then
        logo_source="$LOGO_OUT"
    elif [[ -f "$LOGO_OUT" ]]; then
        logo_source="$LOGO_OUT"
    fi
fi

cat > "$CFG_FILE" <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "__LOGO_SOURCE__",
    "type": "__LOGO_TYPE__",
    "width": 24
  },
  "display": {
    "separator": " : ",
  },
  "modules": [
    {
      "type": "command",
      "key": "  ",
      "keyColor": "blue",
      "text": "if command -v hyprctl >/dev/null 2>&1; then hyprctl splash 2>/dev/null || echo 'RPRice'; else echo 'RPRice'; fi"
    },
    {
      "type": "custom",
      "format": "┌─────────────────────────────────────────────────────────┐"
    },
    {
      "type": "chassis",
      "key": " 󰇺 Chassis",
      "format": "{1} {2} {3}"
    },
    {
      "type": "os",
      "key": " 󰣇 OS",
      "format": "{2}",
      "keyColor": "red"
    },
    {
      "type": "kernel",
      "key": "  Kernel",
      "format": "{2}",
      "keyColor": "red"
    },
    {
      "type": "packages",
      "key": " 󰏗 Packages",
      "keyColor": "green"
    },
    {
      "type": "display",
      "key": " 󰍹 Display",
      "format": "{1}x{2} @ {3}Hz [{7}]",
      "keyColor": "green"
    },
    {
      "type": "terminal",
      "key": "  Terminal",
      "keyColor": "yellow"
    },
    {
      "type": "wm",
      "key": " 󱗃 WM",
      "format": "{2}",
      "keyColor": "yellow"
    },
    {
      "type": "custom",
      "format": "└─────────────────────────────────────────────────────────┘"
    },
    "break",
    {
      "type": "title",
      "key": "  ",
      "format": "{6}{7}{8}"
    },
    {
      "type": "custom",
      "format": "┌─────────────────────────────────────────────────────────┐"
    },
    {
      "type": "cpu",
      "format": "{1} @ {7}",
      "key": "  CPU",
      "keyColor": "blue"
    },
    {
      "type": "gpu",
      "format": "{1} {2}",
      "key": " 󰊴 GPU",
      "keyColor": "blue"
    },
    {
      "type": "gpu",
      "format": "{3}",
      "key": "  GPU Driver",
      "keyColor": "magenta"
    },
    {
      "type": "memory",
      "key": "  Memory ",
      "keyColor": "magenta"
    },
    {
      "type": "disk",
      "key": " 󱦟 OS Age ",
      "folders": "/",
      "keyColor": "red",
      "format": "{days} days"
    },
    {
      "type": "uptime",
      "key": " 󱫐 Uptime ",
      "keyColor": "red"
    },
    {
      "type": "custom",
      "format": "└─────────────────────────────────────────────────────────┘"
    },
    {
      "type": "colors",
      "paddingLeft": 2,
      "symbol": "circle"
    },
    "break"
  ]
}
EOF

sed -i \
    -e "s|__LOGO_SOURCE__|${logo_source}|g" \
    -e "s|__LOGO_TYPE__|${logo_type}|g" \
    "$CFG_FILE"

chmod 0644 "$CFG_FILE"
