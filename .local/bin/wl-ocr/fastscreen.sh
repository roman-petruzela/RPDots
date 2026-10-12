#!/bin/bash
TMP_IMG="$(mktemp --suffix=.png)"
trap 'rm -f "$TMP_IMG"' EXIT

if ! grim -g "$(slurp)" "$TMP_IMG"; then
    exit 1
fi

tesseract "$TMP_IMG" - -l ces+eng 2>/dev/null | wl-copy
