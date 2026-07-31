#!/usr/bin/env bash
set -euo pipefail

if command -v eww >/dev/null 2>&1 && pgrep -x eww >/dev/null 2>&1; then
  eww reload >/dev/null 2>&1 || true
fi
