import Quickshell
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

// Menu vypnutí (Mod+Shift+E): zamknout, uspat, odhlásit, restart, vypnout.
// Celá obrazovka jako u pickeru tapet — okna pod ním rozmazává niri (layer-rule
// rp-overlay, xray false), uprostřed řada dlaždic. Šipky + Enter, písmena jako
// zkratky, Esc nebo klik vedle zavře.
PanelWindow {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // Glyfy jsou FontAwesome z Nerd Fontu: lock, moon-o, sign-out, refresh, power-off
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

    function open() {
        selected = 0
        opener.show()
    }

    function toggle() {
        if (visible) visible = false
        else open()
    }

    function run(i) {
        visible = false
        Quickshell.execDetached(actions[i].cmd)
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.background, 0.4)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
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
            case Qt.Key_Escape:  root.visible = false; break
            default: {
                const i = root.actions.findIndex(a => a.key === event.text.toUpperCase())
                if (i < 0) return
                root.run(i)
            }
            }
            event.accepted = true
        }

        Row {
            anchors.centerIn: parent
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

                    // Klávesová zkratka v rohu
                    Text {
                        anchors { top: parent.top; right: parent.right; margins: 12 }
                        text: tile.modelData.key
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        color: Qt.alpha(Colors.onSurfaceVariant, 0.7)
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = tile.index
                        onClicked: root.run(tile.index)
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
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
