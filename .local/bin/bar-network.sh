#!/usr/bin/env bash
set -uo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/rp-bar-network.state"

human() {
    awk -v b="$1" 'BEGIN {
        split("B K M G T", u)
        i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        printf "%.1f%s", b, u[i]
    }'
}

iface=$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')

if [[ -z "$iface" ]]; then
    jq -nc '{text:"󰖪 offline", tooltip:"offline", class:["disconnected"]}'
    exit 0
fi

ipaddr=$(ip -4 -brief addr show "$iface" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
cidr=$(ip -4 -brief addr show "$iface" 2>/dev/null | awk '{print $3}' | cut -d/ -f2)
gwaddr=$(ip -4 route show default dev "$iface" 2>/dev/null | awk '{print $3; exit}')

is_wifi=0
[[ -d "/sys/class/net/$iface/wireless" ]] && is_wifi=1

now=$(date +%s.%N)
rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)

down_rate=0
up_rate=0
if [[ -f "$STATE" ]]; then
    read -r prev_iface prev_now prev_rx prev_tx <"$STATE" || true
    if [[ "${prev_iface:-}" == "$iface" ]]; then
        elapsed=$(awk -v a="$now" -v b="$prev_now" 'BEGIN{d=a-b; print (d>0)?d:1}')
        down_rate=$(awk -v a="$rx" -v b="$prev_rx" -v e="$elapsed" 'BEGIN{d=a-b; print (d>0)?d/e:0}')
        up_rate=$(awk -v a="$tx" -v b="$prev_tx" -v e="$elapsed" 'BEGIN{d=a-b; print (d>0)?d/e:0}')
    fi
fi
printf '%s %s %s %s\n' "$iface" "$now" "$rx" "$tx" >"$STATE"

down_h=$(human "$down_rate")
up_h=$(human "$up_rate")

if [[ -z "$ipaddr" ]]; then
    jq -nc --arg ifname "$iface" \
        '{text:("󰌘 " + $ifname + " (no IP)"), tooltip:$ifname, class:["linked"]}'
    exit 0
fi

if [[ "$is_wifi" -eq 1 ]]; then
    essid=$(nmcli -t -f active,ssid dev wifi list ifname "$iface" 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
    signal=$(nmcli -t -f active,signal dev wifi list ifname "$iface" 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
    text="  󰇚${down_h} 󰕒${up_h}"
    tooltip="  ${essid:-?}
${iface}
IP ${ipaddr}
Mask ${cidr:-?}
GW ${gwaddr:-?}
Signal ${signal:-?}%"
    jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip, class:["wifi"]}'
else
    text="󰌘  󰇚${down_h} 󰕒${up_h}"
    tooltip="󰌘 ${iface}
IP ${ipaddr}
Mask ${cidr:-?}
GW ${gwaddr:-?}"
    jq -nc --arg text "$text" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip, class:["ethernet"]}'
fi
