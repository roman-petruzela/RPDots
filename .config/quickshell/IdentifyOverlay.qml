import Quickshell
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

Scope {
    id: root
    property bool active: false

    function run() {
        active = true
        hideTimer.restart()
    }

    Timer { id: hideTimer; interval: 2500; onTriggered: root.active = false }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.active || card.opacity > 0
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rp-identify"
            mask: Region {}

            PopupCard {
                id: card
                shown: root.active
                anchors.centerIn: parent
                width: Math.max(260, info.implicitWidth + 64)
                height: info.implicitHeight + 44

                Column {
                    id: info
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.modelData.name
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                        color: Colors.primary
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.modelData.name.startsWith("eDP") ? "Laptop display" : (win.modelData.model || "")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: Colors.onSurfaceVariant
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.modelData.width + " × " + win.modelData.height
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Colors.onSurfaceVariant
                    }
                }
            }
        }
    }
}
