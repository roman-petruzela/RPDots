#!/usr/bin/env bash
# Darkens kitty background to 50% brightness so it's tinted but readable
set -euo pipefail

exec "$HOME/.local/bin/kitty-theme-postprocess.sh"
