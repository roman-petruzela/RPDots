import QtQuick
import "Colors.js" as Colors

Rectangle {
    property string icon: ""
    signal clicked()

    width: 30
    height: 30
    radius: 8
    color: mouseArea.containsMouse ? Colors.surfaceContainerHighest : "transparent"

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Text {
        anchors.centerIn: parent
        text: parent.icon
        font.pixelSize: 14
        color: Colors.onSurfaceVariant
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.clicked()
    }
}
