import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: 160

    property real cpuUsage: 0
    property real ramUsage: 0
    property real diskUsage: 0

    Process {
        id: sysProc
        command: ["bash", "-c",
            "cpu=$(grep 'cpu ' /proc/stat | awk '{idle=$5; total=$2+$3+$4+$5+$6+$7+$8; print 100-int(idle/total*100)}');" +
            "ram=$(free | awk '/^Mem/ {printf \"%.0f\", $3/$2*100}');" +
            "disk=$(df / | awk 'NR==2 {printf \"%.0f\", $3/$2*100}');" +
            "echo \"$cpu $ram $disk\""
        ]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(" ")
                if (parts.length >= 3) {
                    cpuUsage = parseFloat(parts[0]) || 0
                    ramUsage = parseFloat(parts[1]) || 0
                    diskUsage = parseFloat(parts[2]) || 0
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
    }
}
