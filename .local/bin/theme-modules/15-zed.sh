#!/usr/bin/env bash
set -euo pipefail

ZED_SETTINGS="$HOME/.config/zed/settings.json"
THEME_NAME="RPRice Dark"

[[ -f "$ZED_SETTINGS" ]] || exit 0

python3 - "$ZED_SETTINGS" "$THEME_NAME" <<'PY'
import sys, re, json

path, theme_name = sys.argv[1], sys.argv[2]
raw = open(path).read()

def strip_line_comments(text):
    result = []
    for line in text.splitlines():
        stripped = re.sub(r'(?<!:)//.*$', '', line)
        result.append(stripped)
    return '\n'.join(result)

cleaned = strip_line_comments(raw)
try:
    data = json.loads(cleaned)
except json.JSONDecodeError:
    cleaned = re.sub(r',\s*([}\]])', r'\1', cleaned)
    data = json.loads(cleaned)

data['theme'] = theme_name
data['themes'] = {'mode': 'dark', 'light': theme_name, 'dark': theme_name}

with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY
