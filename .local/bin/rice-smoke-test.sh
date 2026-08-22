#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "[smoke] $1" >&2
  exit 1
}

[[ -f "$HOME/.config/kitty/current-theme.conf" ]] || fail "missing kitty theme"
grep -q '^background' "$HOME/.config/kitty/current-theme.conf" || fail "kitty theme malformed"

if [[ -d "$HOME/.config/vesktop/settings" ]]; then
  [[ -f "$HOME/.config/vesktop/settings/quickCss.css" ]] || fail "missing vesktop quickCss"
  grep -q -- '--rp-bg' "$HOME/.config/vesktop/settings/quickCss.css" || fail "vesktop css malformed"
  if [[ -f "$HOME/.config/vesktop/settings/settings.json" ]]; then
    jq -e '.useQuickCss == true' "$HOME/.config/vesktop/settings/settings.json" >/dev/null || fail "vesktop useQuickCss off"
  fi
fi

if [[ -d "$HOME/.config/spicetify/Themes/PywalDynamic" ]]; then
  [[ -f "$HOME/.config/spicetify/Themes/PywalDynamic/color.ini" ]] || fail "missing spicetify color.ini"
  grep -q '^\[wal\]' "$HOME/.config/spicetify/Themes/PywalDynamic/color.ini" || fail "spicetify color.ini malformed"
fi

if [[ -f "$HOME/.config/Code/User/settings.json" ]]; then
  jq -e '.["workbench.colorCustomizations"] != null' "$HOME/.config/Code/User/settings.json" >/dev/null || fail "vscode colors missing"
fi

if [[ -f "$HOME/.config/fastfetch/config.jsonc" ]]; then
  grep -q 'json_schema' "$HOME/.config/fastfetch/config.jsonc" || true
fi

echo "[smoke] ok"
