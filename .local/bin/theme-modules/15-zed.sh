#!/usr/bin/env bash
set -euo pipefail

ZED_SETTINGS="$HOME/.config/zed/settings.json"
THEME_NAME="RPRice Dark"

[[ -f "$ZED_SETTINGS" ]] || exit 0

# matugen already wrote ~/.config/zed/themes/rprice.json via its template.
# Update settings.json (JSONC with // comments) to reference this theme.
# Python handles stripping // comments before parsing and writes back as JSON.
python3 - "$ZED_SETTINGS" "$THEME_NAME" <<'PY'
import sys, re, json

path, theme_name = sys.argv[1], sys.argv[2]
raw = open(path).read()

# Strip // line comments (outside strings — good enough for Zed's settings.json)
def strip_line_comments(text):
    result = []
    for line in text.splitlines():
        # Remove comment only if // appears outside a string context on that line
        stripped = re.sub(r'(?<!:)//.*$', '', line)
        result.append(stripped)
    return '\n'.join(result)

cleaned = strip_line_comments(raw)
try:
    data = json.loads(cleaned)
except json.JSONDecodeError:
    # If it still fails, try removing trailing commas too
    cleaned = re.sub(r',\s*([}\]])', r'\1', cleaned)
    data = json.loads(cleaned)

data['theme'] = theme_name
data['themes'] = {'mode': 'dark', 'light': theme_name, 'dark': theme_name}

# Write back without comments (Zed is fine with clean JSON)
with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY
