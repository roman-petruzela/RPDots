#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/niri"
TARGET="$HOME/.config/niri/theme-colors.kdl"
TMP="$(mktemp "${TARGET}.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<EOF
layout {
  background-color "rgba(0, 0, 0, 0.0)"
  focus-ring {
      active-color "${accent}"
      inactive-color "${color8}"
      active-gradient from="${accent_blue}" to="${accent}" angle=45
  }

  tab-indicator {
      active-color "${accent}"
      inactive-color "${color8}"
      urgent-color "${accent_urgent}"
  }

  // Rámeček je vypnutý v config.kdl; zapíná ho okno Settings (settings.kdl
  // mu dá jen on/šířku, barvy jdou odsud, ať sedí s tapetou)
  border {
      active-color "${accent}"
      inactive-color "${color8}"
      urgent-color "${accent_urgent}"
  }
}
EOF

# config.kdl includes this file, so a bad value here takes the *whole* niri config
# down, not just the colors — `niri validate` then refuses to load anything and the
# desktop keeps running on the last good config with no way to reload. Check the
# candidate against the real config before it replaces the current one.
if command -v niri >/dev/null 2>&1 && [[ -f "$TARGET" ]]; then
    BACKUP="$(mktemp "${TARGET}.bak.XXXXXX")"
    cp -a "$TARGET" "$BACKUP"
    mv -f "$TMP" "$TARGET"
    if ! niri validate >/dev/null 2>&1; then
        mv -f "$BACKUP" "$TARGET"
        echo "30-niri: generated theme-colors.kdl failed niri validate, kept previous" >&2
        exit 1
    fi
    rm -f "$BACKUP"
else
    mv -f "$TMP" "$TARGET"
fi
