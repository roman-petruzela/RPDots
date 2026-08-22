import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: barCount * (barW + barGap) + 8
    implicitHeight: parent ? parent.height : 40

    readonly property int barW: 3
    readonly property int barGap: 2
    readonly property int barCount: 14
    readonly property int maxH: 24

    property var levels: Array(barCount).fill(0)

    Process {
        id: cavaProc
        command: ["cava", "-p", Qt.resolvedUrl("cava-bar.ini").toString().replace(/^file:\/\//, "")]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().replace(/;$/, "").split(";")
                var arr = []
                for (var i = 0; i < root.barCount; i++) {
                    arr.push(parseInt(parts[i]) || 0)
                }
                root.levels = arr
            }
        }
    }

    Row {
        id: bars
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.barGap

        Repeater {
            id: barsRepeater
            model: root.barCount

            delegate: Item {
                required property int index
                width: root.barW
                height: root.maxH

                Rectangle {
                    property real frac: (root.levels[index] || 0) / 7.0
                    height: Math.max(2, Math.round(parent.height * frac))
                    width: parent.width
                    anchors.bottom: parent.bottom
                    radius: 1.5
                    color: {
                        var f = frac
                        return Qt.rgba(
                            Qt.color(Colors.primary).r * (0.5 + 0.5 * f) + Qt.color(Colors.secondary).r * (1 - f) * 0.5,
                            Qt.color(Colors.primary).g * (0.5 + 0.5 * f) + Qt.color(Colors.secondary).g * (1 - f) * 0.5,
                            Qt.color(Colors.primary).b * (0.5 + 0.5 * f) + Qt.color(Colors.secondary).b * (1 - f) * 0.5,
                            0.85
                        )
                    }
                    Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }
    }
}
