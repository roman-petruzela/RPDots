#!/usr/bin/env bash
set -euo pipefail

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/protonvpn-autoconnect.log"
exec >>"$LOG" 2>&1
echo "[$(date)] autoconnect start"

for _ in $(seq 1 30); do
    pgrep -x protonvpn-app >/dev/null 2>&1 && break
    sleep 1
done

if ! pgrep -x protonvpn-app >/dev/null 2>&1; then
    echo "[$(date)] protonvpn-app nespuštěn, konec"
    exit 1
fi

sleep 5

python3 - <<'PY'
import asyncio, sys
async def connect():
    try:
        from proton.vpn.core.api import ProtonVPNAPI
        from proton.vpn.core.session.dataclasses import LoginResult
        api = ProtonVPNAPI()
        await api.connect(protocol="wireguard")
        print("VPN připojena")
    except Exception as e:
        print(f"Chyba: {e}", file=sys.stderr)
        sys.exit(1)
asyncio.run(connect())
PY

echo "[$(date)] autoconnect hotov"
