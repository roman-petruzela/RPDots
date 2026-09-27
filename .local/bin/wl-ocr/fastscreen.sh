#!/bin/bash
TMP_IMG="/tmp/ocr_screenshot.png"

if ! grim -g "$(slurp)" "$TMP_IMG"; then
    exit 1
fi

tesseract "$TMP_IMG" - -l ces+eng 2>/dev/null | wl-copy

rm "$TMP_IMG"

