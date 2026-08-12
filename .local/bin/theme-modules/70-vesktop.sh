#!/usr/bin/env bash
set -euo pipefail

settings_file="$HOME/.config/vesktop/settings/settings.json"
if command -v jq >/dev/null 2>&1 && [[ -f "$settings_file" ]]; then
    tmp="$(mktemp)"
    jq '.useQuickCss = true' "$settings_file" > "$tmp" && mv "$tmp" "$settings_file"
fi
