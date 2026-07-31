import QtQuick
import "Colors.js" as Colors

Item {
    property string label: ""
    property real value: 0.0
    property string unit: "%"
    property color barColor: Colors.primary

    implicitWidth: 300
    implicitHeight: 40

    Column {
        anchors.fill: parent
        spacing: 6

        Row {
            width: parent.width

            Text {
                text: label
                font.pixelSize: 12
                color: Colors.onSurfaceVariant
                width: parent.width * 0.5
            }

            Text {
                text: Math.round(value) + unit
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Colors.onSurface
                width: parent.width * 0.5
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Colors.surfaceContainerHighest

            Rectangle {
                width: parent.width * Math.min(value / 100.0, 1.0)
                height: parent.height
                radius: 2
                color: barColor

                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
