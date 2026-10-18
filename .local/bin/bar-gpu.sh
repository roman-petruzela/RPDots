#!/usr/bin/env bash
set -uo pipefail

DGPU_PCI=$("$HOME/.local/bin/rp-gpu" dgpu)
IGPU=$("$HOME/.local/bin/rp-gpu" igpu)

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'; }

igpu_busy=""; igpu_lines=""
if [[ -r "$IGPU/gpu_busy_percent" ]]; then
    igpu_busy=$(cat "$IGPU/gpu_busy_percent" 2>/dev/null)
    used=$(cat "$IGPU/mem_info_vram_used" 2>/dev/null || echo 0)
    total=$(cat "$IGPU/mem_info_vram_total" 2>/dev/null || echo 0)
    temp=""
    for h in "$IGPU"/hwmon/hwmon*; do
        [[ -r "$h/temp1_input" ]] || continue
        temp=$(( $(cat "$h/temp1_input") / 1000 ))
        break
    done
    igpu_lines="AMD $([[ -n $DGPU_PCI ]] && echo iGPU || echo GPU)"
    igpu_lines+=$'\n'"  load  ${igpu_busy} %"
    (( total > 0 )) && igpu_lines+=$'\n'"  VRAM  $(( used / 1048576 )) / $(( total / 1048576 )) MiB"
    [[ -n "$temp" ]] && igpu_lines+=$'\n'"  temp  ${temp} °C"
fi

dgpu_busy=""; dgpu_lines=""
rt=$(cat "$DGPU_PCI/power/runtime_status" 2>/dev/null || echo "")

if [[ "$rt" == "suspended" ]]; then
    dgpu_lines=$'NVIDIA dGPU\n  asleep (0 W)'
elif command -v nvidia-smi >/dev/null 2>&1; then
    name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
    read -r util memu memt gtemp power clk < <(
        nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,clocks.gr \
                   --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ','
    )
    if [[ -n "${util:-}" ]]; then
        dgpu_busy="$util"
        dgpu_lines="${name:-NVIDIA dGPU}"
        dgpu_lines+=$'\n'"  load  ${util} %"
        dgpu_lines+=$'\n'"  VRAM  ${memu} / ${memt} MiB"
        dgpu_lines+=$'\n'"  temp  ${gtemp} °C"
        dgpu_lines+=$'\n'"  power ${power} W"
        dgpu_lines+=$'\n'"  clock ${clk} MHz"
    fi
fi

if [[ -n "$dgpu_busy" ]]; then
    text="󰢮 ${dgpu_busy}%"
elif [[ -n "$igpu_busy" ]]; then
    text="󰢮 ${igpu_busy}%"
else
    text="󰢮 –"
fi

tooltip="$dgpu_lines"
[[ -n "$tooltip" && -n "$igpu_lines" ]] && tooltip+=$'\n\n'
tooltip+="$igpu_lines"

printf '{"text":"%s","tooltip":"%s","class":"gpu"}\n' \
    "$(json_escape "$text")" "$(json_escape "$tooltip")"
