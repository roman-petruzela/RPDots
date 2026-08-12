#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
ENV_FILE="$STATE_DIR/theme-env.sh"
mkdir -p "$STATE_DIR"

hex="${background#\#}"
r=$((16#${hex:0:2}))
g=$((16#${hex:2:2}))
b=$((16#${hex:4:2}))

lum=$(( (2126 * r + 7152 * g + 722 * b) / 10000 ))

if (( lum >= 140 )); then
  glamour="light"
  colorfgbg="0;15"
else
  glamour="dark"
  colorfgbg="15;0"
fi

cat > "$ENV_FILE" <<EOF
#!/usr/bin/env bash
export COLORFGBG="${colorfgbg}"
export GLAMOUR_STYLE="${glamour}"
export GH_COLOR_LABELS=1
EOF

chmod 0644 "$ENV_FILE"
