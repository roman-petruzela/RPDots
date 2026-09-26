import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Tenký posuvník: viditelný jen při posouvání nebo najetí myší
ScrollBar {
    id: sb
    policy: ScrollBar.AsNeeded
    implicitWidth: hovered || pressed ? 8 : 5
    padding: 2
    Behavior on implicitWidth { NumberAnimation { duration: 120 } }

    contentItem: Rectangle {
        radius: width / 2
        color: sb.pressed ? Colors.primary : Qt.alpha(Colors.onSurface, sb.hovered ? 0.45 : 0.3)
        opacity: sb.active || sb.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    background: Item {}
}
