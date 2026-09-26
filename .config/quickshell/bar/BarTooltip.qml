import Quickshell
import QtQuick
import "../Colors.js" as Colors

// Tooltip panelu: malé okno pod položkou (jako tooltip ve waybaru), ukáže se
// po krátké prodlevě, ať při přejíždění myší přes panel neblikají.
PopupWindow {
    id: tip
    required property Item target
    property string text: ""
    property bool show: false

    anchor.item: target
    anchor.rect.x: target.width / 2 - implicitWidth / 2
    anchor.rect.y: target.height + 10
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12
    color: "transparent"
    visible: false

    Timer {
        id: delay
        interval: 450
        onTriggered: tip.visible = tip.show && tip.text !== ""
    }
    onShowChanged: {
        if (show) delay.restart()
        else { delay.stop(); visible = false }
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Qt.alpha(Colors.surfaceContainerHigh, 0.97)
        border.width: 1
        border.color: Qt.alpha(Colors.primary, 0.4)
        Text {
            id: label
            anchors.centerIn: parent
            text: tip.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Colors.onSurface
        }
    }
}
