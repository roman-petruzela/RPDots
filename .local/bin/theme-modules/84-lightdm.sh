#!/usr/bin/env bash
set -euo pipefail

command -v rp-lightdm-sync-apply >/dev/null 2>&1 || exit 0
sudo -n rp-lightdm-sync-apply
