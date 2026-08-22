import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 30
    implicitHeight: parent ? parent.height : 40

    property bool hovered: false

    Text {
        anchors.centerIn: parent
        text: "󰐥"
        font.pixelSize: 14
        font.family: "JetBrainsMono Nerd Font"
        color: parent.hovered
            ? Colors.primary
            : Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.45)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: parent.hovered = true
        onExited:  parent.hovered = false
        onClicked: Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["qs", "ipc", "call", "dashboard", "toggle"]; running: true }',
            parent, "dashToggle"
        )
    }
}
