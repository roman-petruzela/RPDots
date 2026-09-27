import Quickshell.Widgets
import QtQuick
import "Colors.js" as Colors

Item {
    id: root

    required property var niri
    property var tiles: []
    property bool icons: true

    Repeater {
        model: root.tiles

        Rectangle {
            required property var modelData
            x: modelData.x; y: modelData.y
            width: modelData.w; height: modelData.h
            radius: Math.min(4, width / 4, height / 4)
            color: modelData.hl && !root.icons
                ? Qt.alpha(Colors.primary, 0.85)
                : Qt.alpha(Colors.surfaceContainerHighest, 0.88)
            border.width: modelData.hl && root.icons ? 1.5 : 1
            border.color: modelData.hl ? Colors.primary : Qt.alpha(Colors.outline, 0.5)

            IconImage {
                visible: root.icons
                anchors.centerIn: parent
                implicitSize: Math.max(10, Math.min(32, Math.min(parent.width, parent.height) * 0.5))
                source: root.icons ? root.niri.appIcon(parent.modelData.appId) : ""
            }
        }
    }
}
