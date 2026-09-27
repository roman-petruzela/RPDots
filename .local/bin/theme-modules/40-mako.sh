#!/usr/bin/env bash
set -euo pipefail

[[ -f "$HOME/.config/mako/rp-settings" ]] || "$HOME/.local/bin/rp-settings" apply >/dev/null 2>&1 || true

if command -v makoctl >/dev/null 2>&1; then
    makoctl reload 2>/dev/null || true
fi
