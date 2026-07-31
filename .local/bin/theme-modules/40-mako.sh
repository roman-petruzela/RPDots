#!/usr/bin/env bash
# MAKO: matugen generates mako/config directly — this module only reloads
set -euo pipefail

if command -v makoctl >/dev/null 2>&1; then
    makoctl reload 2>/dev/null || true
fi
