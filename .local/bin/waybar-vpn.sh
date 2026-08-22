#!/usr/bin/env bash
set -euo pipefail

command -v nmcli >/dev/null 2>&1 || exit 0

mapfile -t vpn_lines < <(
  nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null |
    awk -F: '$2 ~ /^(vpn|wireguard|openvpn|l2tp|pptp|tailscale|zerotier)$/ { print $1 "|" $2 "|" $3 }'
)

if [[ ${#vpn_lines[@]} -eq 0 ]]; then
  printf '{"text":"","tooltip":"","class":["vpn","off"]}\n'
  exit 0
fi

details=()
for line in "${vpn_lines[@]}"; do
  IFS='|' read -r name type device <<<"$line"
  details+=("$name ($type on ${device:-?})")
done

label="$(printf '%s\n' "${vpn_lines[0]}" | awk -F'|' '{print $1}')"
if [[ "$label" =~ ([A-Z]{2}-?FREE#[0-9]+|PRO#[0-9]+) ]]; then
  label="${BASH_REMATCH[1]}"
else
  # Extract last part after last space
  label="${label##* }"
fi
tooltip="$(printf '%s\n' "${details[@]}")"

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg text "󰖂 $label" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip, class:["vpn","on"]}'
else
  printf '{"text":"󰖂 %s","tooltip":"%s","class":["vpn","on"]}\n' "$label" "$tooltip"
fi
