import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

// Přehled systému. Procento samo o sobě moc neřekne, proto každý řádek nese
// i konkrétní čísla — teplotu a takt CPU, obsazené GiB, zbývající čas baterie.
Item {
    implicitWidth: 340
    implicitHeight: col.implicitHeight

    // Obnovovat jen při otevřeném dashboardu — pak ale každou sekundu a hned
    // po otevření, ať neukazuje čísla z doby, kdy byl naposledy vidět
    property bool active: true

    property real cpuUsage: 0
    property real ramUsage: 0
    property real diskUsage: 0
    property real batteryLevel: 0

    property string cpuDetail: ""
    property string ramDetail: ""
    property string diskDetail: ""
    property string batteryDetail: ""
    property string uptime: ""
    property string loadAvg: ""
    property bool hasBattery: false
    readonly property bool charging: batteryDetail.indexOf("to full") >= 0

    Process {
        id: sysProc
        // Jeden shell na všechno — pět procesů každou sekundu by bylo zbytečné.
        command: ["bash", "-c", `
            f="\${XDG_RUNTIME_DIR:-/tmp}/qs-cpu-prev"
            prev=$(cat "$f" 2>/dev/null || echo '0 0 0 0 0 0 0')
            # Po delší pauze (dashboard zavřený) by vyšel průměr za celou dobu —
            # místo toho krátký vzorek teď
            if [ $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) )) -gt 3 ]; then
                prev=$(awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat)
                sleep 0.25
            fi
            cur=$(awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat)
            echo "$cur" > "$f"
            cpu=$(awk -v p="$prev" -v c="$cur" 'BEGIN{
                split(p,P); split(c,C)
                dt=(C[1]+C[2]+C[3]+C[4]+C[5]+C[6]+C[7])-(P[1]+P[2]+P[3]+P[4]+P[5]+P[6]+P[7])
                di=C[4]-P[4]
                if (dt>0) printf "%.0f", 100*(1-di/dt); else printf "0"
            }')

            # k10temp je teplota jádra; acpitz je záložní, když ho ovladač nedá
            temp=""
            for h in /sys/class/hwmon/hwmon*; do
                [ "$(cat "$h/name" 2>/dev/null)" = "k10temp" ] || continue
                temp=$(( $(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000 )); break
            done
            [ -z "$temp" ] && [ -r /sys/class/thermal/thermal_zone0/temp ] &&
                temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
            ghz=$(awk '/cpu MHz/{s+=$4;n++} END{ if(n>0) printf "%.1f", s/n/1000 }' /proc/cpuinfo)

            read -r ram_pct ram_det < <(free -b | awk '/^Mem/{
                printf "%.0f %.1f/%.0f GiB", $3/$2*100, $3/1073741824, $2/1073741824 }')
            read -r disk_pct disk_det < <(df -B1 / | awk 'NR==2{
                printf "%.0f %.0f/%.0f GiB", $3/$2*100, $3/1073741824, $2/1073741824 }')

            bat=""; bat_det=""; charging=0
            for d in /sys/class/power_supply/BAT*; do
                [ -r "$d/capacity" ] || continue
                bat=$(cat "$d/capacity")
                status=$(cat "$d/status" 2>/dev/null)
                [ "$status" = "Charging" ] && charging=1
                now=$(cat "$d/energy_now" 2>/dev/null || echo 0)
                full=$(cat "$d/energy_full" 2>/dev/null || echo 0)
                pw=$(cat "$d/power_now" 2>/dev/null || echo 0)
                if [ "$pw" -gt 0 ]; then
                    # zbývající energie / aktuální odběr = hodiny do konce
                    if [ "$charging" = 1 ]; then rem=$(( full - now )); else rem="$now"; fi
                    bat_det=$(awk -v r="$rem" -v p="$pw" 'BEGIN{
                        h=r/p; printf "%dh %02dm", int(h), int((h-int(h))*60) }')
                    [ "$charging" = 1 ] && bat_det="$bat_det to full"
                else
                    bat_det=$([ "$status" = "Full" ] && echo "full" || echo "$status")
                fi
                break
            done

            up=$(awk '{d=int($1/86400); h=int($1%86400/3600); m=int($1%3600/60);
                       if (d>0) printf "%dd %dh", d, h; else printf "%dh %dm", h, m}' /proc/uptime)
            load=$(awk '{print $1", "$2", "$3}' /proc/loadavg)

            printf '%s\\t%s °C · %s GHz\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \\
                "$cpu" "\${temp:-?}" "\${ghz:-?}" "$ram_pct" "$ram_det" \\
                "$disk_pct" "$disk_det" "\${bat:--}" "$bat_det" "$up" "$load"
        `]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split("\t")
                if (p.length < 10) return
                cpuUsage      = parseFloat(p[0]) || 0
                cpuDetail     = p[1]
                ramUsage      = parseFloat(p[2]) || 0
                ramDetail     = p[3]
                diskUsage     = parseFloat(p[4]) || 0
                diskDetail    = p[5]
                hasBattery    = p[6] !== "-"
                batteryLevel  = parseFloat(p[6]) || 0
                batteryDetail = p[7]
                uptime        = p[8]
                loadAvg       = p[9]
            }
        }
    }

    Timer { interval: 1000; running: active; repeat: true; triggeredOnStart: true; onTriggered: sysProc.running = true }

    Column {
        id: col
        width: parent.width
        spacing: 6

        StatBar {
            width: parent.width
            label: "CPU"
            detail: cpuDetail
            value: cpuUsage
            barColor: cpuUsage > 80 ? Colors.errorColor : Colors.primary
        }
        StatBar {
            width: parent.width
            label: "RAM"
            detail: ramDetail
            value: ramUsage
            barColor: ramUsage > 85 ? Colors.errorColor : Colors.secondary
        }
        StatBar {
            width: parent.width
            label: "Disk"
            detail: diskDetail
            value: diskUsage
            barColor: diskUsage > 90 ? Colors.errorColor : Colors.tertiary
        }
        StatBar {
            visible: hasBattery
            width: parent.width
            label: charging ? "Bat 󰂄" : "Battery"
            detail: batteryDetail
            value: batteryLevel
            barColor: batteryLevel <= 15 ? Colors.errorColor
                    : batteryLevel <= 30 ? "#e8a400"
                    : Colors.secondary
        }

        // Údaje, které nemají smysl jako proužek
        Row {
            width: parent.width
            topPadding: 4
            spacing: 8

            Text {
                text: "󰅐 " + uptime
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.outline
            }
            Item { width: parent.width - 210; height: 1 }
            Text {
                text: "load " + loadAvg
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.outline
            }
        }
    }
}
