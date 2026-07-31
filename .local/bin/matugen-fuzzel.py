#!/usr/bin/env python3
"""Generate fuzzel colors from matugen JSON on stdin or from a saved file."""
import sys
import json
import os

wall = os.path.expanduser("~/.local/share/wallpapers/current")
cache = os.path.expanduser("~/.cache/matugen/current-colors.json")

data = {}
try:
    import subprocess
    result = subprocess.run(
        ["matugen", "image", wall, "--source-color-index", "0", "-j", "hex", "--dry-run"],
        capture_output=True, text=True
    )
    txt = result.stdout.strip()
    if txt:
        data = json.loads(txt[txt.index("{"):])
except Exception:
    pass

if not data:
    sys.exit(0)

colors = {k: v["default"]["color"].lstrip("#") for k, v in data.get("colors", {}).items()}

def c(key, fallback="000000"):
    return colors.get(key, fallback)

fuzzel_config = f"""[main]
font=JetBrainsMono Nerd Font:size=12
prompt="  "
lines=12
width=48
horizontal-pad=20
vertical-pad=12
inner-pad=10
layer=overlay
dpi-aware=no

[colors]
background={c("surface_container", "271e19")}e6
text={c("on_surface", "f0dfd7")}ff
prompt={c("primary", "ffb68c")}ff
placeholder={c("outline", "9f8d84")}ff
input={c("on_surface", "f0dfd7")}ff
match={c("primary", "ffb68c")}ff
selection={c("primary_container", "6f3812")}ff
selection-text={c("on_primary_container", "ffdbc9")}ff
selection-match={c("primary", "ffb68c")}ff
counter={c("outline", "9f8d84")}ff
border={c("outline_variant", "52443c")}ff

[border]
width=1
radius=12
"""

out = os.path.expanduser("~/.config/fuzzel/fuzzel.ini")
with open(out, "w") as f:
    f.write(fuzzel_config)

print(f"fuzzel: colors updated → {out}")
