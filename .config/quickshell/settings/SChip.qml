import QtQuick
import "../Colors.js" as Colors

Rectangle {
    id: chip
    property string text
    property int count: -1
    property bool selected: false
    signal clicked()

    width: chipRow.width + 24
    height: 30
    radius: 15
    color: selected ? Qt.alpha(Colors.primary, 0.22)
        : chipHover.hovered ? Qt.alpha(Colors.onSurface, 0.06) : "transparent"
    border.width: 1
    border.color: selected ? Qt.alpha(Colors.primary, 0.6) : Colors.outlineVariant
    Behavior on color { ColorAnimation { duration: 120 } }
    HoverHandler { id: chipHover }

    Row {
        id: chipRow
        anchors.centerIn: parent
        height: parent.height
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: chip.selected ? Colors.onSurface : Colors.onSurfaceVariant
        }
        Text {
            visible: chip.count >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: chip.count
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: chip.selected ? Colors.primary : Colors.outline
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
