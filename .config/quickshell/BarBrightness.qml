import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: row.implicitWidth + 8
    implicitHeight: parent ? parent.height : 40

    property int pct: 100

    Process {
        id: brightProc
        command: ["bash", "-c",
            "d=$(ls /sys/class/backlight/ 2>/dev/null | head -1); " +
            "[ -z \"$d\" ] && echo 100 && exit; " +
            "cur=$(cat /sys/class/backlight/$d/brightness 2>/dev/null || echo 0); " +
            "max=$(cat /sys/class/backlight/$d/max_brightness 2>/dev/null || echo 1); " +
            "echo $((cur * 100 / max))"]
        stdout: SplitParser {
            onRead: data => { root.pct = parseInt(data.trim()) || 100 }
        }
    }

    Timer {
        interval: 3000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: { brightProc.running = false; brightProc.running = true }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 3

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pct >= 66 ? "󰃠" : root.pct >= 33 ? "󰃟" : "󰃞"
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.6)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pct + "%"
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.6)
        }
    }
}
