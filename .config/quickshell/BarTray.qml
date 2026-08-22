import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: 26
    implicitHeight: parent ? parent.height : 40
    visible: true

    property bool open: false
    property var  screen: null
    property real popupRightMargin: 4  // set from Bar.qml: barBg.width - (rightSection.x + barTray.x + barTray.implicitWidth)

    Rectangle {
        id: btn
        anchors.centerIn: parent
        width: 22; height: 22; radius: 6
        color: root.open
            ? Qt.rgba(Qt.color(Colors.primary).r, Qt.color(Colors.primary).g, Qt.color(Colors.primary).b, 0.20)
            : ma.containsMouse
                ? Qt.rgba(Qt.color(Colors.surfaceContainerHighest).r,
                          Qt.color(Colors.surfaceContainerHighest).g,
                          Qt.color(Colors.surfaceContainerHighest).b, 0.80)
                : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: root.open ? "" : ""
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            color: root.open
                ? Colors.primary
                : Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.65)
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    PanelWindow {
        id: popupWin
        visible: root.open
        color: "transparent"
        screen: root.screen

        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; right: true }
        margins.top: 42
        margins.right: root.popupRightMargin

        implicitWidth:  card.implicitWidth
        implicitHeight: card.implicitHeight

        Rectangle {
            id: card
            anchors.fill: parent
            implicitWidth:  trayGrid.implicitWidth  + 16
            implicitHeight: trayGrid.implicitHeight + 16
            radius: 10
            color: Qt.rgba(Qt.color(Colors.surfaceContainerHigh).r,
                           Qt.color(Colors.surfaceContainerHigh).g,
                           Qt.color(Colors.surfaceContainerHigh).b, 0.97)
            border.color: Qt.rgba(Qt.color(Colors.outlineVariant).r,
                                  Qt.color(Colors.outlineVariant).g,
                                  Qt.color(Colors.outlineVariant).b, 0.55)
            border.width: 1

            Grid {
                id: trayGrid
                anchors { fill: parent; margins: 8 }
                columns: 5
                spacing: 4

                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        required property SystemTrayItem modelData
                        width: 28; height: 28

                        Image {
                            id: ico
                            anchors.centerIn: parent
                            width: 18; height: 18
                            sourceSize { width: 18; height: 18 }
                            source: {
                                var ic = modelData.icon
                                if (!ic) return ""
                                if (ic.startsWith("/") || ic.startsWith("file://") || ic.startsWith("image://"))
                                    return ic
                                return "image://icon/" + ic
                            }
                            fillMode: Image.PreserveAspectFit
                            smooth: true; asynchronous: true
                            visible: status === Image.Ready
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            visible: !ico.visible
                            width: 18; height: 18; radius: 4
                            color: Qt.rgba(Qt.color(Colors.primary).r,
                                           Qt.color(Colors.primary).g,
                                           Qt.color(Colors.primary).b, 0.18)
                            Text {
                                anchors.centerIn: parent
                                text: (modelData.title || modelData.id || "?").charAt(0).toUpperCase()
                                font.pixelSize: 10; font.weight: Font.Bold
                                font.family: "JetBrainsMono Nerd Font"
                                color: Colors.primary
                            }
                        }

                        Rectangle {
                            anchors.fill: parent; radius: 6
                            color: itemMa.containsMouse
                                ? Qt.rgba(Qt.color(Colors.primary).r, Qt.color(Colors.primary).g, Qt.color(Colors.primary).b, 0.12)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: itemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: e => {
                                if (e.button === Qt.LeftButton)
                                    modelData.activate()
                                else if (e.button === Qt.RightButton && modelData.hasMenu)
                                    modelData.menu.open(parent, 0, parent.height + 2)
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.open = false
        }
    }
}
