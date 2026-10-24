#!/usr/bin/env bash
set -uo pipefail
shopt -s nullglob

lines=()
for h in /sys/class/hwmon/hwmon*; do
    name=$(<"$h/name")
    [[ $name == nvme ]] && name=$(basename "$(readlink -f "$h/device")")
    for t in "$h"/temp*_input; do
        label=$(cat "${t%_input}_label" 2>/dev/null || echo "")
        [[ $name == nvme* && -n $label && $label != Composite ]] && continue
        v=$(( $(cat "$t" 2>/dev/null || echo 0) / 1000 ))
        (( v > 0 )) || continue
        key=$name; [[ -n $label && $label != Composite ]] && key+=" $label"
        lines+=("$(printf '%-16s%4d °C' "$key" "$v")")
    done
done

tip=$(printf '%s\n' "${lines[@]}")
printf '{"tooltip":"%s"}\n' "$(printf '%s' "$tip" | sed ':a;N;$!ba;s/\n/\\n/g')"
