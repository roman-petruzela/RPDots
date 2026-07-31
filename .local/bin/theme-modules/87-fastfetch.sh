#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
CFG_FILE="$CFG_DIR/config.jsonc"
LOGO_HELPER="$HOME/.local/bin/fastfetch-logo.sh"
logo_source=""
logo_type="kitty" # Změň na "w3m", pokud nepoužíváš kitty a používáš w3m-img

# Prioritně zkusíme načíst náš dynamický pywal smajlík
if [[ -x "$LOGO_HELPER" ]]; then
    logo_source="$("$LOGO_HELPER" logo --dynamic 2>/dev/null || true)"
    if [[ -z "$logo_source" ]]; then
        logo_source="$("$LOGO_HELPER" logo --local 2>/dev/null || true)"
    fi
fi

# Fallback, pokud skript neexistuje nebo nenašel obrázek
if [[ -z "$logo_source" || ! -f "$logo_source" ]]; then
    logo_source="arch"
    logo_type="auto"
fi

# HLAVNÍ KONFIGURACE
cat >"$CFG_FILE" <<'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "arch",
    "type": "auto"
  },
  "display": {
    "separator": " : ",
  },
  "modules": [
    {
      "type": "command",
      "key": "  ",
      "keyColor": "blue",
      "text": "if command -v hyprctl >/dev/null 2>&1; then hyprctl splash 2>/dev/null || echo 'Niri Rice'; else echo 'Niri Rice'; fi"
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

# Nahrazení placeholderů
sed -i \
    -e "s|__LOGO_SOURCE__|$logo_source|g" \
    -e "s|__LOGO_TYPE__|$logo_type|g" \
    "$CFG_FILE"

chmod 0644 "$CFG_FILE"
