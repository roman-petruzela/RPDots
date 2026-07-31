import Quickshell
import Quickshell.Io
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
    property string networkInfo: ""

    Process {
        id: netProc
        command: ["bash", "-c",
            "iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}');" +
            "if [ -z \"$iface\" ]; then echo 'Offline'; exit; fi;" +
            "ssid=$(iw dev \"$iface\" link 2>/dev/null | awk '/SSID:/ {print substr($0, index($0,$2))}');" +
            "ipaddr=$(ip -4 addr show \"$iface\" 2>/dev/null | awk '/inet / {split($2,a,\"/\"); print a[1]; exit}');" +
            "if [ -n \"$ssid\" ]; then printf '%s  %s' \"$ssid\" \"${ipaddr:-}\"; " +
            "else printf '%s  %s' \"$iface\" \"${ipaddr:-}\"; fi"
        ]
        running: true
        stdout: SplitParser {
            onRead: function(line) { root.networkInfo = line.trim() }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    Behavior on slideX {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    onVisibleChanged: {
        if (visible) {
            slideX = 0
            netProc.running = true
        } else {
            slideX = 380
        }
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

        // Left border accent
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

        Flickable {
            anchors {
                fill: parent
                topMargin: 48
                bottomMargin: 20
                leftMargin: 20
                rightMargin: 20
            }
            contentHeight: contentCol.implicitHeight
            clip: true

            Column {
                id: contentCol
                width: parent.width
                spacing: 0

                // Clock
                ClockWidget {
                    width: parent.width
                }

                // Network row under clock
                Text {
                    width: parent.width
                    text: networkInfo
                    font.pixelSize: 12
                    color: Colors.onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 8
                    bottomPadding: 20
                    elide: Text.ElideRight
                }

                Divider { width: parent.width }

                Item { width: parent.width; height: 20 }

                SectionLabel { title: "Systém" }

                Item { width: parent.width; height: 12 }

                SystemWidget {
                    width: parent.width
                }

                Item { width: parent.width; height: 20 }

                Divider { width: parent.width; visible: mediaWidget.visible }

                Item { width: parent.width; height: mediaWidget.visible ? 20 : 0; visible: mediaWidget.visible }

                SectionLabel {
                    title: "Přehrávač"
                    visible: mediaWidget.visible
                }

                Item { width: parent.width; height: mediaWidget.visible ? 12 : 0; visible: mediaWidget.visible }

                MediaWidget {
                    id: mediaWidget
                    width: parent.width
                }
            }
        }
    }
}
