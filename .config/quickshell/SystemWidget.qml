import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: (hasBattery ? 4 : 3) * 36 + (hasBattery ? 3 : 2) * 10

    property real cpuUsage: 0
    property real ramUsage: 0
    property real diskUsage: 0
    property real batteryLevel: 0
    property string batteryStatus: ""
    property bool hasBattery: false

    Process {
        id: sysProc
        command: ["bash", "-c",
            "prev=$(cat /tmp/qs-cpu-prev 2>/dev/null || echo '0 0 0 0 0 0 0');" +
            "cur=$(grep '^cpu ' /proc/stat | awk '{print $2,$3,$4,$5,$6,$7,$8}');" +
            "echo \"$cur\" > /tmp/qs-cpu-prev;" +
            "cpu=$(awk -v p=\"$prev\" -v c=\"$cur\" 'BEGIN{" +
            "  split(p,P); split(c,C);" +
            "  idle_p=P[4]; total_p=P[1]+P[2]+P[3]+P[4]+P[5]+P[6]+P[7];" +
            "  idle_c=C[4]; total_c=C[1]+C[2]+C[3]+C[4]+C[5]+C[6]+C[7];" +
            "  dt=total_c-total_p; di=idle_c-idle_p;" +
            "  if(dt>0) printf \"%.0f\", 100*(1-di/dt); else print 0" +
            "}');" +
            "ram=$(free | awk '/^Mem/{printf \"%.0f\",$3/$2*100}');" +
            "disk=$(df / | awk 'NR==2{printf \"%.0f\",$3/$2*100}');" +
            "bat='none'; bst='none';" +
            "for d in /sys/class/power_supply/BAT*; do [ -f \"$d/capacity\" ] && bat=$(cat \"$d/capacity\") && bst=$(cat \"$d/status\") && break; done;" +
            "echo \"$cpu $ram $disk $bat $bst\""
        ]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var p = line.trim().split(" ")
                if (p.length < 3) return
                cpuUsage  = parseFloat(p[0]) || 0
                ramUsage  = parseFloat(p[1]) || 0
                diskUsage = parseFloat(p[2]) || 0
                if (p.length >= 5 && p[3] !== "none") {
                    hasBattery    = true
                    batteryLevel  = parseFloat(p[3]) || 0
                    batteryStatus = p[4] || ""
                } else {
                    hasBattery = false
                }
            }
        }
    }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: sysProc.running = true }

    Column {
        anchors.fill: parent
        spacing: 10

        StatBar {
            width: parent.width
            label: "CPU"
            value: cpuUsage
            barColor: cpuUsage > 80 ? Colors.errorColor : Colors.primary
        }
        StatBar {
            width: parent.width
            label: "RAM"
            value: ramUsage
            barColor: ramUsage > 85 ? Colors.errorColor : Colors.secondary
        }
        StatBar {
            width: parent.width
            label: "Disk"
            value: diskUsage
            barColor: diskUsage > 90 ? Colors.errorColor : Colors.tertiary
        }
        StatBar {
            visible: hasBattery
            width: parent.width
            label: batteryStatus === "Charging" ? "Battery ⚡" : "Battery"
            value: batteryLevel
            barColor: batteryLevel <= 15 ? Colors.errorColor
                    : batteryLevel <= 30 ? "#e8a400"
                    : Colors.secondary
        }
    }
}
