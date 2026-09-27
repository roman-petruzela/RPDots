#!/usr/bin/env bash
set -euo pipefail

settings_file="$HOME/.config/vesktop/settings/settings.json"
generated="$HOME/.config/vesktop/settings/quickCss.generated.css"
live="$HOME/.config/vesktop/settings/quickCss.css"

if [[ -f "$generated" ]]; then
    cat "$generated" > "$live"
fi

if command -v jq >/dev/null 2>&1 && [[ -f "$settings_file" ]]; then
    tmp="$(mktemp)"
    jq '.useQuickCss = true' "$settings_file" > "$tmp" && mv "$tmp" "$settings_file"
fi
