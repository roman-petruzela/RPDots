#!/bin/bash

# Dočasný soubor pro screenshot
TMP_IMG="/tmp/ocr_screenshot.png"

# 1. Vyber výřez a udělej screenshot
if ! grim -g "$(slurp)" "$TMP_IMG"; then
    exit 1 # Pokud uživatel zruší výběr (Esc), skript skončí
fi

# 2. Rozpoznání textu (v češtině a angličtině) a zkopírování do schránky
tesseract "$TMP_IMG" - -l ces+eng 2>/dev/null | wl-copy

# 3. Úklid dočasného souboru
rm "$TMP_IMG"

# Volitelné: Oznámení o úspěchu (vyžaduje nainstalovaný dunst/mako apod.)
# notify-send "OCR" "Text byl zkopírován do schránky."
