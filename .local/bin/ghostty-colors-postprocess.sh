#!/usr/bin/env bash
# Darkens Ghostty background to 50% HSV brightness (same logic as kitty postprocess)
set -euo pipefail

COLORS_FILE="${HOME}/.config/ghostty/colors.conf"
[[ -f "$COLORS_FILE" ]] || exit 0

python3 - "$COLORS_FILE" <<'PY'
import sys, re, colorsys

path = sys.argv[1]
text = open(path).read()

m = re.search(r'^background\s*=\s*#([0-9a-fA-F]{6})', text, re.MULTILINE)
if not m:
    sys.exit(0)

r, g, b = (int(m.group(1)[i:i+2], 16) / 255 for i in (0, 2, 4))
h, s, v = colorsys.rgb_to_hsv(r, g, b)
r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v * 0.5)
dark = f'#{int(r2*255):02x}{int(g2*255):02x}{int(b2*255):02x}'

text = re.sub(r'^(background\s*=\s*)#[0-9a-fA-F]{6}', f'\\g<1>{dark}', text, flags=re.MULTILINE)
open(path, 'w').write(text)
PY
