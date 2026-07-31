#!/usr/bin/env bash
set -euo pipefail
# priority: 5

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
THUMB_DIR="$CACHE_DIR/wallpaper-thumbs"
WAL_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wal"
MAX_BYTES=$((1024 * 1024 * 512)) # 512 MB
MAX_AGE_DAYS=21

mkdir -p "$THUMB_DIR"

find "$THUMB_DIR" -type f -mtime "+$MAX_AGE_DAYS" -delete 2>/dev/null || true
find "$WAL_CACHE" -type f -mtime "+$MAX_AGE_DAYS" -delete 2>/dev/null || true

current_size="$(du -sb "$CACHE_DIR" 2>/dev/null | awk '{print $1}')"
if [[ -z "${current_size:-}" ]]; then
  exit 0
fi

if (( current_size > MAX_BYTES )); then
  find "$CACHE_DIR" -type f -printf '%T@ %p\n' \
    | sort -n \
    | while IFS= read -r line; do
        file="${line#* }"
        rm -f "$file"
        current_size="$(du -sb "$CACHE_DIR" 2>/dev/null | awk '{print $1}')"
        (( current_size <= MAX_BYTES )) && break
      done
fi
