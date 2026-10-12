#!/usr/bin/env bash
set -euo pipefail

if command -v qs >/dev/null 2>&1; then
    qs ipc call shell reload 2>/dev/null || true
fi
