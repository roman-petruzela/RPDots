import QtQuick
import "../Colors.js" as Colors

Item {
    id: s
    property string icon: ""
    property int value: 0
    property bool dimmed: false
    signal moved(int v)
    signal released(int v)
    signal iconClicked()

    implicitHeight: 44
    readonly property bool dragging: drag.pressed
    property int dragValue: 0
    readonly property int shown: dragging ? dragValue : value

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Colors.surfaceContainerHigh
        clip: true

        Rectangle {
            height: parent.height
            width: Math.max(track.height, track.width * Math.min(100, s.shown) / 100)
            radius: height / 2
            color: s.dimmed ? Colors.outline : Colors.primary
            Behavior on width { enabled: !s.dragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function pick(x) { return Math.round(Math.max(0, Math.min(1, x / width)) * 100) }
        onPressed: e => { s.dragValue = pick(e.x); throttle.restart() }
        onPositionChanged: e => { s.dragValue = pick(e.x); if (!throttle.running) throttle.restart() }
        onReleased: { throttle.stop(); s.released(s.dragValue) }
        onWheel: w => s.released(Math.max(0, Math.min(100, s.value + (w.angleDelta.y > 0 ? 5 : -5))))
    }
    Timer { id: throttle; interval: 60; onTriggered: s.moved(s.dragValue) }

    Text {
        id: ic
        x: 0; width: s.height; height: s.height
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        text: s.icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 18
        color: s.dimmed ? Colors.surface : Colors.onPrimary
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: s.iconClicked() }
    }
    Text {
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        text: s.shown
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: (track.width * s.shown / 100) > track.width - 40 ? Colors.onPrimary : Colors.onSurfaceVariant
    }
}
