import Quickshell
import QtQuick
import "Colors.js" as Colors

Item {
    id: root

    implicitWidth: 340
    implicitHeight: 52

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    property string armed: ""
    property real armedAt: 0

    readonly property var actions: [
        { id: "lock",   icon: "\u{f033e}", label: "Lock",      confirm: false, cmd: [bin + "rp-lock"] },
        { id: "reboot", icon: "\u{f0709}", label: "Restart",   confirm: true,  cmd: ["systemctl", "reboot"] },
        { id: "power",  icon: "\u{f0425}", label: "Shut down", confirm: true,  cmd: ["systemctl", "poweroff"] },
    ]

    function press(a) {
        if (!a.confirm) { Quickshell.execDetached(a.cmd); return }
        if (armed !== a.id) {
            armed = a.id
            armedAt = Date.now()
            disarm.restart()
            return
        }
        if (Date.now() - armedAt < 300) return
        armed = ""
        Quickshell.execDetached(a.cmd)
    }

    Timer { id: disarm; interval: 4000; onTriggered: root.armed = "" }

    Row {
        anchors.fill: parent
        spacing: 8

        Repeater {
            model: root.actions

            Rectangle {
                id: btn
                required property var modelData
                readonly property bool isArmed: root.armed === modelData.id

                width: (root.width - 16) / 3
                height: root.height
                radius: 14
                color: isArmed ? Qt.alpha(Colors.errorColor, hover.containsMouse ? 0.32 : 0.24)
                     : hover.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                border.width: isArmed ? 1 : 0
                border.color: Colors.errorColor
                Behavior on color { ColorAnimation { duration: 140 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.isArmed ? "\u{f012c}" : btn.modelData.icon
                        font.pixelSize: 17
                        font.family: "JetBrainsMono Nerd Font"
                        color: btn.isArmed ? Colors.errorColor : Colors.onSurface
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.isArmed ? "Confirm" : btn.modelData.label
                        font.pixelSize: 10
                        font.weight: btn.isArmed ? Font.DemiBold : Font.Normal
                        font.family: "JetBrainsMono Nerd Font"
                        color: btn.isArmed ? Colors.errorColor : Colors.onSurfaceVariant
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.press(btn.modelData)
                }
            }
        }
    }
}
