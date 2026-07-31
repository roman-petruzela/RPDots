import Quickshell
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    anchors {
        right: true
        top: true
        bottom: true
    }

    implicitWidth: 380
    margins.right: 0
    margins.top: 0
    margins.bottom: 0

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region {
        item: panel
    }

    property real slideX: visible ? 0 : 380

    Behavior on slideX {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    onVisibleChanged: {
        if (visible) slideX = 0
        else slideX = 380
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: panel
        x: parent.width - width + slideX
        y: 0
        width: 380
        height: parent.height

        color: Qt.rgba(
            Qt.color(Colors.surfaceContainer).r,
            Qt.color(Colors.surfaceContainer).g,
            Qt.color(Colors.surfaceContainer).b,
            0.88
        )
        radius: 0

        Rectangle {
            x: 0; y: 0
            width: 1
            height: parent.height
            color: Colors.outlineVariant
            opacity: 0.5
        }

        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 48
                leftMargin: 20
                rightMargin: 20
            }
            spacing: 28

            ClockWidget {
                width: parent.width
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.outlineVariant
                opacity: 0.4
            }

            Column {
                width: parent.width
                spacing: 14

                SectionLabel {
                    title: "Systém"
                }

                SystemWidget {
                    width: parent.width
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.outlineVariant
                opacity: 0.4
                visible: mediaWidget.visible
            }

            Column {
                width: parent.width
                spacing: 14
                visible: mediaWidget.visible

                SectionLabel {
                    title: "Přehrávač"
                }

                MediaWidget {
                    id: mediaWidget
                    width: parent.width
                }
            }
        }
    }
}
