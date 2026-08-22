import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: row.implicitWidth + 8
    implicitHeight: parent ? parent.height : 40

    property int cpu: 0
    property int mem: 0
    property int gpu: 0
    property int temp: 0

    Process {
        id: statProc
        command: ["bash", "-c", "~/.local/bin/qs-sysstat.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var j = JSON.parse(data)
                    root.cpu  = j.cpu  || 0
                    root.mem  = j.mem  || 0
                    root.gpu  = j.gpu  || 0
                    root.temp = j.temp || 0
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 2000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: { statProc.running = false; statProc.running = true }
    }

    function tempColor(t) {
        if (t >= 85) return Colors.errorColor
        if (t >= 70) return Colors.tertiary
        return Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.65)
    }

    function usageColor(v) {
        if (v >= 85) return Colors.errorColor
        if (v >= 65) return Colors.tertiary
        return Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.65)
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 10

        StatChip { icon: ""; value: root.cpu;  unit: "%"; col: root.usageColor(root.cpu) }
        StatChip { icon: "󰢮"; value: root.gpu;  unit: "%"; col: root.usageColor(root.gpu) }
        StatChip { icon: ""; value: root.mem;  unit: "%"; col: root.usageColor(root.mem) }
        StatChip { icon: ""; value: root.temp; unit: "\u00b0"; col: root.tempColor(root.temp) }
    }

    component StatChip: Row {
        property string icon: ""
        property int    value: 0
        property string unit: "%"
        property color  col: "white"
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: icon
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            color: col
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: value + unit
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            color: col
            font.weight: Font.Medium
        }
    }
}
