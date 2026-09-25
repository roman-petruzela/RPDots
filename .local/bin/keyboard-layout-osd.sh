#!/usr/bin/env bash
# Přepnutí layoutu klávesnice dělá sám niri (built-in `switch-layout`), ale
# built-in akce nejde v jednom bindu zkombinovat se spawnem OSD. Proto tenhle
# skript zavolá přepnutí přes `niri msg action` a hned za ním vyvolá OSD —
# stejný vzor jako u volume-osd.sh / brightness-osd.sh.
niri msg action switch-layout "${1:-next}" >/dev/null 2>&1

# Hodnotu (aktuální layout) si OSD načte samo přes `niri msg keyboard-layouts`
# — `qs ipc call` v quickshellu 0.3.0 neumí předat argument.
"$HOME/.local/bin/rp-shell" osd-keyboard-layout trigger || true
