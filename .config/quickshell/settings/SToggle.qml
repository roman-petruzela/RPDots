import QtQuick
import "../Colors.js" as Colors

Rectangle {
    id: tg
    property bool checked
    signal toggled(bool value)

    width: 46; height: 26; radius: 13
    color: checked ? Colors.primary : Colors.surfaceContainerHighest
    border.width: 1
    border.color: checked ? Colors.primary : Colors.outlineVariant
    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
        width: 20; height: 20; radius: 10
        anchors.verticalCenter: parent.verticalCenter
        x: tg.checked ? tg.width - width - 3 : 3
        color: tg.checked ? Colors.onPrimary : Colors.outline
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tg.toggled(!tg.checked)
    }
}
