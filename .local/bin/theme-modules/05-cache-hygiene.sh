#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"

find "$CACHE_DIR/wallpaper-thumbs" -type f -mtime +21 -delete 2>/dev/null || true
find "$CACHE_DIR/deploy-backup" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true
