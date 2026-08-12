#!/usr/bin/env bash
set -euo pipefail

THEME="$HOME/.config/kitty/current-theme.conf"
[[ -f "$THEME" ]] || exit 0

python3 - "$THEME" <<'PY'
import colorsys, re, sys

path = sys.argv[1]
text = open(path).read()

m = re.search(r'^background\s+(#[0-9a-fA-F]{6})', text, re.MULTILINE)
if not m:
    sys.exit(0)

h = m.group(1)
r, g, b = int(h[1:3], 16)/255, int(h[3:5], 16)/255, int(h[5:7], 16)/255
hue, s, v = colorsys.rgb_to_hsv(r, g, b)
r2, g2, b2 = colorsys.hsv_to_rgb(hue, s, v * 0.5)
dark = f'#{int(r2*255):02x}{int(g2*255):02x}{int(b2*255):02x}'

text = re.sub(r'^(background\s+)#[0-9a-fA-F]{6}', f'\\g<1>{dark}', text, flags=re.MULTILINE)
open(path, 'w').write(text)
print(dark)
PY
