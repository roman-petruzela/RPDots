#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$OUT_DIR"
FILE="$OUT_DIR/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"

GEOM="$(slurp)"
if [[ -z "${GEOM:-}" ]]; then
  exit 0
fi

grim -g "$GEOM" "$FILE"
wl-copy < "$FILE"

if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "rice" "Screenshot" "Vystrizek ulozen a zkopirovan do schranky."
fi
