import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: row.implicitWidth + 8
    implicitHeight: parent ? parent.height : 40

    property int  vol: 0
    property bool muted: false

    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: line => {
                var m = line.match(/Volume:\s+([\d.]+)(\s+\[MUTED\])?/)
                if (m) {
                    root.vol   = Math.round(parseFloat(m[1]) * 100)
                    root.muted = !!m[2]
                }
            }
        }
    }
    Timer {
        interval: 1000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: { volProc.running = false; volProc.running = true }
    }

    Process { id: volUpProc;   command: ["bash", "-c", "$HOME/.local/bin/rp-audio volume up"] }
    Process { id: volDownProc; command: ["bash", "-c", "$HOME/.local/bin/rp-audio volume down"] }
    Process { id: muteProc;    command: ["bash", "-c", "$HOME/.local/bin/rp-audio mute toggle"] }
    Process { id: switcherProc; command: ["qs", "ipc", "call", "audio", "toggle"] }

    function refresh() {
        Qt.callLater(() => { volProc.running = false; volProc.running = true })
    }

    function adjustVol(up) {
        const p = up ? volUpProc : volDownProc
        p.running = false
        p.running = true
        refresh()
    }

    function toggleMute() {
        muteProc.running = false
        muteProc.running = true
        refresh()
    }

    function openSwitcher() {
        switcherProc.running = false
        switcherProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: e => root.adjustVol(e.angleDelta.y > 0)
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "󰝟" : root.vol >= 60 ? "󰕾" : root.vol >= 20 ? "󰖀" : "󰕿"
            font.pixelSize: 14
            font.family: "JetBrainsMono Nerd Font"
            color: root.muted
                ? Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.35)
                : Colors.primary
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMute()
                onWheel: e => root.adjustVol(e.angleDelta.y > 0)
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "–" : root.vol + "%"
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.7)
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openSwitcher()
                onWheel: e => root.adjustVol(e.angleDelta.y > 0)
            }
        }
    }
}
