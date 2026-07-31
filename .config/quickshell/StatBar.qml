import QtQuick
import "Colors.js" as Colors

Item {
    property string label:    ""
    property real   value:    0.0
    property color  barColor: Colors.primary

    implicitWidth:  300
    implicitHeight: 36

    Row {
        anchors.fill: parent

        Text {
            width: 52
            anchors.verticalCenter: parent.verticalCenter
            text: label
            font.pixelSize: 12
            color: Colors.onSurfaceVariant
        }

        Item {
            width: parent.width - 52 - 40
            height: parent.height

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.surfaceContainerHighest

                Rectangle {
                    width: parent.width * Math.min(value / 100.0, 1.0)
                    height: parent.height
                    radius: 2
                    color: barColor
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }

        Text {
            width: 40
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(value) + "%"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: "JetBrains Mono"
            color: Colors.onSurface
            horizontalAlignment: Text.AlignRight
        }
    }
}
