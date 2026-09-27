#!/usr/bin/env bash
niri msg action switch-layout "${1:-next}" >/dev/null 2>&1

"$HOME/.local/bin/rp-shell" osd-keyboard-layout trigger || true
