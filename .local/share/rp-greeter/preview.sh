#!/usr/bin/env bash
# Náhled přihlašovací obrazovky v běžné session, bez greetd:
#
#   ~/.local/share/rp-greeter/preview.sh [výstup]     (výchozí: zaostřený monitor)
#
# Heslo „test“ náhled zavře, cokoli jiného ukáže chybu; Esc smaže pole.
# Colors.js a tapeta se berou z tvé session, ne z /usr/share (to je kopie
# pro uživatele greeter, kterou dělá rp-lightdm-sync-apply).
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/greeter"
DIR="${XDG_RUNTIME_DIR:-/tmp}/rp-greeter-preview"
OUT="${1:-$(niri msg --json focused-output | jq -r .name)}"

rm -rf "$DIR"
mkdir -p "$DIR"
cp "$SRC"/*.qml "$DIR"/
cp "$HOME/.config/quickshell/Colors.js" "$DIR"/

RP_GREETER_TEST=1 RP_GREETER_SCREEN="$OUT" \
RP_GREETER_WALLPAPER="$HOME/.local/share/wallpapers/current" \
RP_GREETER_USER="$USER" \
    exec qs -p "$DIR"
