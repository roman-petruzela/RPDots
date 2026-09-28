#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/greeter"
DIR="${XDG_RUNTIME_DIR:-/tmp}/rp-greeter-preview"
OUT="${1:-$(niri msg --json focused-output | jq -r .name)}"

rm -rf "$DIR"
mkdir -p "$DIR"
cp "$SRC"/*.qml "$DIR"/
install -Dm644 "$SRC/../../../../.config/quickshell/lock/LockContent.qml" "$DIR/lock/LockContent.qml"
cp "$HOME/.config/quickshell/Colors.js" "$DIR"/

RP_GREETER_TEST=1 RP_GREETER_SCREEN="$OUT" \
RP_GREETER_WALLPAPER="$HOME/.local/share/wallpapers/current" \
RP_GREETER_USER="$USER" \
    exec qs -p "$DIR"
