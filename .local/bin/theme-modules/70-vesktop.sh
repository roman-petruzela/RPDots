#!/usr/bin/env bash
set -euo pipefail

settings_file="$HOME/.config/vesktop/settings/settings.json"
generated="$HOME/.config/vesktop/settings/quickCss.generated.css"
live="$HOME/.config/vesktop/settings/quickCss.css"

if [[ -f "$generated" ]]; then
    bg=$(awk '$1 == "background" { print $2; exit }' "$HOME/.config/kitty/current-theme.conf" 2>/dev/null)
    alpha=${RP_ALPHA:-$("$HOME/.local/bin/rp-settings" get theme.terminal_opacity 2>/dev/null || echo 0.45)}
    { cat "$generated"; printf ':root { %s--rp-alpha: %s; }\n' "${bg:+--rp-term-bg: $bg; }" "$alpha"; } >"$live.tmp"
    cmp -s "$live.tmp" "$live" && rm -f "$live.tmp" || mv -f "$live.tmp" "$live"
fi

if command -v jq >/dev/null 2>&1 && [[ -f "$settings_file" ]]; then
    tmp="$(mktemp)"
    jq '.useQuickCss = true' "$settings_file" > "$tmp" && mv "$tmp" "$settings_file"
fi
