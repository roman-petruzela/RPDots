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
    property var anchorFn: null
    property real anchorX: -1
    readonly property int margin: 8

    function place() { anchorX = anchorFn && screen ? anchorFn(screen.name) : -1 }

    signal opened()

    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    property bool shown: false
    onVisibleChanged: {
        shown = visible
        if (visible) { place(); root.opened() }
    }
    Timer { id: hideTimer; interval: card.closeDuration + 20; onTriggered: if (!root.shown) root.visible = false }

    FocusedOutput { id: opener; window: root }

    function open() {
        hideTimer.stop()
        if (root.visible && !root.shown) { root.place(); root.shown = true; root.opened() }
        opener.show()
    }

    function hide() {
        if (!root.visible || !root.shown) return
        root.shown = false
        hideTimer.restart()
    }

    function toggle() {
        if (root.visible && root.shown) root.hide()
        else root.open()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.hide()
    }

    PopupCard {
        id: card
        shown: root.shown

        x: {
            const max = parent.width - width - root.margin
            return root.anchorX < 0 ? max : Math.max(root.margin, Math.min(max, root.anchorX - width / 2))
        }
        y: Math.max(root.margin, Math.min(root.barHeight + root.margin, parent.height - height - root.margin))

        width: root.cardWidth
        height: col.implicitHeight + 28

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
