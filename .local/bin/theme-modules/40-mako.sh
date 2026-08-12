#!/usr/bin/env bash
set -euo pipefail

if command -v makoctl >/dev/null 2>&1; then
    makoctl reload 2>/dev/null || true
fi
