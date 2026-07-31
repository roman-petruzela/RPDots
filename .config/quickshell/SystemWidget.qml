import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: hasBattery ? 176 : 128

    property real cpuUsage: 0
    property real ramUsage: 0
    property real diskUsage: 0
    property real batteryLevel: 0
    property string batteryStatus: ""
    property bool hasBattery: false

    Process {
        id: sysProc
        command: ["bash", "-c",
            "cpu=$(grep 'cpu ' /proc/stat | awk '{idle=$5; total=$2+$3+$4+$5+$6+$7+$8; print 100-int(idle/total*100)}');" +
            "ram=$(free | awk '/^Mem/ {printf \"%.0f\", $3/$2*100}');" +
            "disk=$(df / | awk 'NR==2 {printf \"%.0f\", $3/$2*100}');" +
            "bat_cap=''; bat_status='';" +
            "for d in /sys/class/power_supply/BAT*; do [ -f \"$d/capacity\" ] && bat_cap=$(cat \"$d/capacity\") && bat_status=$(cat \"$d/status\") && break; done;" +
            "echo \"$cpu $ram $disk ${bat_cap:-none} ${bat_status:-none}\""
        ]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(" ")
                if (parts.length >= 3) {
                    cpuUsage  = parseFloat(parts[0]) || 0
                    ramUsage  = parseFloat(parts[1]) || 0
                    diskUsage = parseFloat(parts[2]) || 0
                    if (parts.length >= 5 && parts[3] !== "none") {
                        hasBattery    = true
                        batteryLevel  = parseFloat(parts[3]) || 0
                        batteryStatus = parts[4] || ""
                    } else {
                        hasBattery = false
                    }
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: sysProc.running = true
    }

    Column {
        anchors.fill: parent
        spacing: 16

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
            label: "Disk  /"
            value: diskUsage
            barColor: diskUsage > 90 ? Colors.errorColor : Colors.tertiary
        }

        StatBar {
            visible: hasBattery
            width: parent.width
            label: batteryStatus === "Charging" ? "Baterie  ⚡" : "Baterie"
            value: batteryLevel
            barColor: batteryLevel <= 15 ? Colors.errorColor
                    : batteryLevel <= 30 ? "#e8a400"
                    : Colors.secondary
        }
    }
}
