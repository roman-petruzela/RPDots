#!/usr/bin/env bash
# Pins the kitty background to a fixed darkness and lifts any ANSI colour that
# would be unreadable against it.
set -euo pipefail

THEME="$HOME/.config/kitty/current-theme.conf"
[[ -f "$THEME" ]] || exit 0

# Target HSV value for the background, and the minimum WCAG contrast ratio an
# ANSI colour has to reach against it.
KITTY_BG_VALUE="${KITTY_BG_VALUE:-0.23}" \
KITTY_MIN_CONTRAST="${KITTY_MIN_CONTRAST:-2.5}" \
python3 - "$THEME" <<'PY'
import colorsys, os, re, sys

path = sys.argv[1]
text = open(path).read()
bg_value = float(os.environ["KITTY_BG_VALUE"])
min_contrast = float(os.environ["KITTY_MIN_CONTRAST"])


def parse(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def fmt(rgb):
    return "#%02x%02x%02x" % tuple(int(round(c * 255)) for c in rgb)


def luminance(rgb):
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


m = re.search(r'^background\s+(#[0-9a-fA-F]{6})', text, re.MULTILINE)
if not m:
    sys.exit(0)

# An absolute target rather than "halve whatever is there": scheme-monochrome
# hands back a *light* primary_container (#d4d4d4 against #583a6f in the coloured
# schemes), so halving left the terminal on a pale grey background. Fixing the
# value also makes this script idempotent — the old relative version darkened the
# theme again on every extra run, which is how a stray `matugen` invocation used
# to leave kitty visibly off.
hue, sat, _ = colorsys.rgb_to_hsv(*parse(m.group(1)))
bg = colorsys.hsv_to_rgb(hue, sat, bg_value)
text = re.sub(r'^(background\s+)#[0-9a-fA-F]{6}', f'\\g<1>{fmt(bg)}',
              text, flags=re.MULTILINE)


def lift(match):
    prefix, h = match.group(1), match.group(2)
    # color0 is ANSI black and is meant to stay dark — programs pick it when they
    # want something recessive, so lifting it to meet contrast defeats the point.
    if prefix.split()[0] == "color0":
        return match.group(0)
    rgb = parse(h)
    if contrast(rgb, bg) >= min_contrast:
        return match.group(0)
    # Raise brightness, keeping hue and saturation, until the colour clears the
    # threshold. In monochrome schemes on_primary_container comes back as pure
    # black, which the template maps onto color10/12/15 — invisible on a dark
    # background.
    hue_c, sat_c, val_c = colorsys.rgb_to_hsv(*rgb)
    for step in range(1, 101):
        cand = colorsys.hsv_to_rgb(hue_c, sat_c, min(1.0, val_c + step / 100.0))
        if contrast(cand, bg) >= min_contrast:
            return f"{prefix}{fmt(cand)}"
    return f"{prefix}#ffffff"


text = re.sub(r'^(color\d+\s+)(#[0-9a-fA-F]{6})', lift, text, flags=re.MULTILINE)
open(path, 'w').write(text)
PY
