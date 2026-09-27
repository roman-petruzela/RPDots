import QtQuick
import "../Colors.js" as Colors

Item {
    id: sp
    property bool running: true
    property int size: 16
    width: size; height: size
    visible: running

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Qt.alpha(Colors.primary, 0.2)
    }
    Canvas {
        id: arc
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = Colors.primary
            c.lineWidth = 2
            c.lineCap = "round"
            c.beginPath()
            c.arc(width / 2, height / 2, width / 2 - 1, 0, Math.PI / 2)
            c.stroke()
        }
        RotationAnimation on rotation {
            running: sp.running && sp.visible
            from: 0; to: 360; duration: 900
            loops: Animation.Infinite
        }
    }
}
