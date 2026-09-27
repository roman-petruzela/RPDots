import QtQuick
import "Colors.js" as Colors

Item {
    property string label:    ""
    property string detail:   ""
    property real   value:    0.0
    property color  barColor: Colors.primary

    implicitWidth:  300
    implicitHeight: 30

    Row {
        anchors.fill: parent
        spacing: 8

        Text {
            width: 42
            anchors.verticalCenter: parent.verticalCenter
            text: label
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.onSurfaceVariant
        }

        Text {
            width: 96
            anchors.verticalCenter: parent.verticalCenter
            text: detail
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            font.pixelSize: 10
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.outline
        }

        Item {
            width: parent.width - 42 - 96 - 42 - 24
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
            width: 42
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(value) + " %"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.onSurface
            horizontalAlignment: Text.AlignRight
        }
    }
}
