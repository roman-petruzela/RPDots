import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

PanelWindow {
    id: root

    default property alias content: col.data

    property string heading: ""
    property int cardWidth: 380
    property int barHeight: 36

    signal opened()

    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    property real slideY: -20

    Behavior on slideY {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    onVisibleChanged: {
        slideY = visible ? 0 : -20
        if (visible) root.opened()
    }

    FocusedOutput { id: opener; window: root }

    function open() { opener.show() }

    function toggle() {
        if (root.visible) root.visible = false
        else root.open()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.visible = false
    }

    Rectangle {
        id: card

        anchors.right: parent.right
        anchors.rightMargin: 8
        y: root.barHeight + 8 + root.slideY

        width: root.cardWidth
        height: col.implicitHeight + 28
        radius: 16

        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        color: Qt.rgba(Qt.color(Colors.surfaceContainer).r,
                       Qt.color(Colors.surfaceContainer).g,
                       Qt.color(Colors.surfaceContainer).b, 0.94)
        border.color: Colors.outlineVariant
        border.width: 1

        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors {
                fill: parent
                topMargin: 14; bottomMargin: 14
                leftMargin: 16; rightMargin: 16
            }
            spacing: 4

            Text {
                text: root.heading
                visible: text !== ""
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.onSurfaceVariant
                bottomPadding: 6
            }
        }
    }
}
