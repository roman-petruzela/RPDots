import Quickshell
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

PanelWindow {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    readonly property var actions: [
        { key: "L", label: "Lock",      glyph: "", cmd: ["swaylock"] },
        { key: "S", label: "Suspend",   glyph: "", cmd: ["systemctl", "suspend"] },
        { key: "E", label: "Log out",   glyph: "", cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { key: "R", label: "Restart",   glyph: "", cmd: ["systemctl", "reboot"] },
        { key: "P", label: "Shut down", glyph: "", cmd: ["systemctl", "poweroff"] }
    ]

    property int selected: 0

    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rp-overlay"
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    FocusedOutput { id: opener; window: root }

    property bool shown: false
    onVisibleChanged: if (visible) shown = true; else shown = false
    function dismiss() { shown = false; hideTimer.restart() }
    Timer { id: hideTimer; interval: card.closeDuration + 20; onTriggered: if (!root.shown) root.visible = false }

    function open() {
        hideTimer.stop()
        selected = 0
        shown = true
        opener.show()
    }

    function toggle() {
        if (visible && shown) dismiss()
        else open()
    }

    function run(i) {
        dismiss()
        Quickshell.execDetached(actions[i].cmd)
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.background, 0.4)
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
    }

    Item {
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            const n = root.actions.length
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_Backtab: root.selected = (root.selected + n - 1) % n; break
            case Qt.Key_Right:
            case Qt.Key_Tab:     root.selected = (root.selected + 1) % n; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:   root.run(root.selected); break
            case Qt.Key_Escape:  root.dismiss(); break
            default: {
                const i = root.actions.findIndex(a => a.key === event.text.toUpperCase())
                if (i < 0) return
                root.run(i)
            }
            }
            event.accepted = true
        }

        PopupCard {
            id: card
            anchors.centerIn: parent
            width: content.width + 56
            height: content.height + 48
            shown: root.shown

            MouseArea { anchors.fill: parent }

            Column {
                id: content
                anchors.centerIn: parent
                spacing: 26

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18

                    Repeater {
                        model: root.actions

                        Rectangle {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool sel: index === root.selected

                            width: 148
                            height: 164
                            radius: 24
                            color: sel
                                ? Qt.alpha(Colors.surfaceContainerHighest, 0.92)
                                : Qt.alpha(Colors.surfaceContainer, 0.62)
                            border.width: sel ? 2 : 1
                            border.color: sel ? Colors.primary : Qt.alpha(Colors.onSurface, 0.1)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 38
                                text: tile.modelData.glyph
                                font.family: root.fontFamily
                                font.pixelSize: 44
                                color: tile.sel ? Colors.primary : Colors.onSurface
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 26
                                text: tile.modelData.label
                                font.family: root.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                color: Colors.onSurface
                            }

                            Text {
                                anchors { top: parent.top; right: parent.right; margins: 12 }
                                text: tile.modelData.key
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                color: Qt.alpha(Colors.onSurfaceVariant, 0.7)
                            }

                            HoverSelect {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onMoved: root.selected = tile.index
                                onClicked: root.run(tile.index)
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 28

                    Repeater {
                        model: [["← →", "choose"], ["Enter", "confirm"], ["Letter", "shortcut"], ["Esc", "close"]]
                        Row {
                            required property var modelData
                            spacing: 7
                            Text {
                                text: modelData[0]
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: Colors.onSurface
                            }
                            Text {
                                text: modelData[1]
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                color: Colors.onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }
}
