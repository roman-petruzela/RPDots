import Quickshell
import QtQuick
import "../notify"
import "../Colors.js" as Colors

Column {
    id: root
    required property var service
    readonly property var items: service ? service.list : []
    spacing: 8

    Item {
        width: parent.width
        height: 22
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.items.length > 0 ? "Notifications  " + root.items.length : "Notifications"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Colors.onSurface
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: root.items.length > 0
            text: "Clear all"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: clearArea.containsMouse ? Colors.primary : Colors.onSurfaceVariant
            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.service.clearAll()
            }
        }
    }

    Text {
        visible: root.items.length === 0
        width: parent.width
        topPadding: 6
        text: root.service && root.service.cfg.dnd ? "Silent mode is on. New notifications wait here."
                                                    : "No new notifications."
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: Colors.onSurfaceVariant
    }

    Repeater {
        model: ScriptModel { values: root.items.slice().reverse() }
        NotifyCard {
            required property var modelData
            width: root.width
            notif: modelData
            service: root.service
        }
    }
}
