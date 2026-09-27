import QtQuick
import "../Colors.js" as Colors

// Dlaždice přepínače v dashboardu: ikona a pod ní krátký popisek.
// Zapnutá má primaryContainer — stejný jazyk jako vybraná položka ve flyoutech.
Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property bool active: false
    property bool busy: false
    signal clicked()

    implicitHeight: 64
    radius: 14
    color: active ? Colors.primaryContainer
         : hover.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
    Behavior on color { ColorAnimation { duration: 140 } }

    readonly property color fg: active ? Colors.onPrimaryContainer : Colors.onSurfaceVariant

    Column {
        anchors.centerIn: parent
        spacing: 4
        opacity: tile.busy ? 0.5 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
            color: tile.active ? Colors.onPrimaryContainer : Colors.onSurface
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: tile.width - 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: tile.fg
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!tile.busy) tile.clicked()
    }
}
