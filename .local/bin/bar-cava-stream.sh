#!/usr/bin/env bash
set -euo pipefail

cfg="$HOME/.config/cava/config"
fifo="$(mktemp -u)"
rm -f "$fifo"
mkfifo "$fifo"

cleanup() {
  rm -f "$fifo"
  if [[ -n "${cava_pid:-}" ]] && kill -0 "$cava_pid" 2>/dev/null; then
    kill "$cava_pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

cava -p "$cfg" >"$fifo" &
cava_pid=$!

sed -u 's/;//g; s/0/▁/g; s/1/▂/g; s/2/▃/g; s/3/▄/g; s/4/▅/g; s/5/▆/g; s/6/▇/g; s/7/█/g;' <"$fifo"
