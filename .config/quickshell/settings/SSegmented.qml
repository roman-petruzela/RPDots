import QtQuick
import "../Colors.js" as Colors

Rectangle {
    id: seg
    property var options: []
    property var labels: []
    property string current
    signal picked(string value)

    width: segRow.width + 6
    height: 32
    radius: 10
    color: Colors.surfaceContainerHighest

    Row {
        id: segRow
        x: 3; y: 3
        spacing: 2
        Repeater {
            model: seg.options
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool sel: String(modelData) === seg.current
                width: Math.max(56, segText.implicitWidth + 22)
                height: 26
                radius: 8
                color: sel ? Colors.primary : segHover.hovered ? Qt.alpha(Colors.onSurface, 0.06) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                HoverHandler { id: segHover }
                Text {
                    id: segText
                    anchors.centerIn: parent
                    text: seg.labels[index] ?? String(modelData)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: sel ? Colors.onPrimary : Colors.onSurfaceVariant
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(String(modelData))
                }
            }
        }
    }
}
