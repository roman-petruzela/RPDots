#!/usr/bin/env bash
# ProtonVPN auto-connect — spouštět až po přihlášení, čeká na daemon
# POZOR: po připojení se odpojí Claude Code a jiné sítě

set -euo pipefail

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/protonvpn-autoconnect.log"
exec >>"$LOG" 2>&1
echo "[$(date)] autoconnect start"

# Počkej na protonvpn-app (max 30s)
for i in $(seq 1 30); do
    pgrep -x protonvpn-app >/dev/null 2>&1 && break
    sleep 1
done

if ! pgrep -x protonvpn-app >/dev/null 2>&1; then
    echo "[$(date)] protonvpn-app nespuštěn, konec"
    exit 1
fi

# Dej GUI čas na inicializaci
sleep 5

# Připoj přes Python API
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
