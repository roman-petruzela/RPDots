#!/usr/bin/env bash
# Fresh-install test: ./install.sh full --yes in a clean Arch container, then verify.sh.
#   tests/install/run.sh            run the test
#   tests/install/run.sh --shell    open a shell in the container afterwards
#   tests/install/run.sh --keep     save the installed container as rpdots-install-test:done
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
ENGINE="$(command -v podman || command -v docker)" || { echo "podman or docker is required" >&2; exit 1; }
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rpdots-install-test"
CTX="$(mktemp -d)"
trap 'rm -rf "$CTX"' EXIT

mkdir -p "$CACHE/pacman" "$CTX/repo"
git -C "$REPO" ls-files -z --cached --others --exclude-standard \
    | tar -C "$REPO" --null -T - -c --ignore-failed-read 2>/dev/null | tar -x -C "$CTX/repo"
cp "$REPO/tests/install/Containerfile" "$CTX/"

"$ENGINE" build -q -t rpdots-install-test -f "$CTX/Containerfile" "$CTX" >/dev/null

cmd='cd ~/dotfiles && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm test
./install.sh full --yes </dev/null && ./tests/install/verify.sh'
[[ "${1:-}" == --shell ]] && cmd+='; exec bash'

tty=(-i); [[ -t 0 ]] && tty+=(-t)
"$ENGINE" rm -f rpdots-install-run >/dev/null 2>&1 || true
rc=0
"$ENGINE" run --name rpdots-install-run "${tty[@]}" -v "$CACHE/pacman:/var/cache/pacman/pkg" \
    rpdots-install-test bash -c "$cmd" || rc=$?
[[ "${1:-}" == --keep ]] && "$ENGINE" commit -q rpdots-install-run rpdots-install-test:done >/dev/null
"$ENGINE" rm -f rpdots-install-run >/dev/null
exit $rc
