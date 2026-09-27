import QtQuick
import "../Colors.js" as Colors

Item {
    id: sl
    property real from: 0
    property real to: 1
    property real value: 0
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    property bool percent: false
    property string zero: ""
    property real live: value
    property bool dragging: false
    signal moved(real value)

    width: 280; height: 26
    onValueChanged: if (!dragging) live = value

    function at(x) {
        const f = Math.max(0, Math.min(1, x / track.width))
        const v = from + Math.round((to - from) * f / step) * step
        return Number(Math.max(from, Math.min(to, v)).toFixed(Math.max(decimals, 2)))
    }

    function label(v) {
        if (zero !== "" && v === 0) return zero
        if (percent) return Math.round(v * 100) + "%"
        return v.toFixed(decimals) + suffix
    }

    Item {
        id: track
        width: parent.width - 70
        height: parent.height
        readonly property real frac: (sl.live - sl.from) / Math.max(sl.to - sl.from, 1e-9)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 4; radius: 2
            color: Colors.surfaceContainerHighest
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * track.frac; height: 4; radius: 2
            color: Colors.primary
        }
        Rectangle {
            width: 18; height: 18; radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * track.frac - width / 2
            color: Colors.primary
            border.width: 3
            border.color: Colors.surfaceContainer
            scale: sl.dragging ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => { sl.dragging = true; sl.live = sl.at(mouse.x - 6) }
            onPositionChanged: mouse => { if (pressed) sl.live = sl.at(mouse.x - 6) }
            onReleased: { sl.dragging = false; sl.moved(sl.live) }
        }
        WheelHandler {
            onWheel: event => sl.moved(Number(Math.max(sl.from, Math.min(sl.to,
                sl.value + (event.angleDelta.y > 0 ? sl.step : -sl.step))).toFixed(Math.max(sl.decimals, 2))))
        }
    }
    Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 62
        horizontalAlignment: Text.AlignRight
        text: sl.label(sl.live)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Colors.onSurfaceVariant
    }
}
