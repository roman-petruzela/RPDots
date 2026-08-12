import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: 44

    Process { id: shotProc;  command: ["niri", "msg", "action", "screenshot"] }
    Process { id: lockProc;  command: ["swaylock"] }
    Process { id: quitProc;  command: ["niri", "msg", "action", "quit"] }

    Row {
        anchors.fill: parent
        spacing: 8

        Repeater {
            model: [
                { icon: "󰹑", label: "Screenshot", accent: Colors.primary,   action: "shot"  },
                { icon: "󰌾", label: "Lock",        accent: Colors.secondary, action: "lock"  },
                { icon: "󰐥", label: "Power",       accent: Colors.errorColor, action: "quit" },
            ]

            Rectangle {
                width: (parent.width - 16) / 3
                height: 44
                radius: 12
                color: hover.containsMouse
                    ? Qt.rgba(Qt.color(modelData.accent).r,
                              Qt.color(modelData.accent).g,
                              Qt.color(modelData.accent).b, 0.18)
                    : Colors.surfaceContainerHigh
                border.color: Qt.rgba(Qt.color(modelData.accent).r,
                                      Qt.color(modelData.accent).g,
                                      Qt.color(modelData.accent).b, 0.3)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        font.pixelSize: 16
                        color: modelData.accent
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        font.pixelSize: 10
                        color: Colors.onSurfaceVariant
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.action === "shot")  shotProc.running = true
                        else if (modelData.action === "lock") lockProc.running = true
                        else if (modelData.action === "quit") quitProc.running = true
                    }
                }
            }
        }
    }
}
