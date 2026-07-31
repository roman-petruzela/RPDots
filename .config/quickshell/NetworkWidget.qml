import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: 28

    property string netLabel: "…"
    property real rxBps: 0
    property real txBps: 0
    property real _rxPrev: -1
    property real _txPrev: -1

    function fmt(bps) {
        if (bps < 1024)        return bps.toFixed(0)    + " B/s"
        if (bps < 1048576)     return (bps / 1024).toFixed(1)    + " K/s"
        return (bps / 1048576).toFixed(2) + " M/s"
    }

    Process {
        id: netProc
        command: ["bash", "-c",
            "iface=$(ip route show default 2>/dev/null | awk '/default/{print $5;exit}');" +
            "if [ -z \"$iface\" ]; then echo 'Offline|0 0'; exit; fi;" +
            "ssid=$(iw dev \"$iface\" link 2>/dev/null | awk '/SSID:/{sub(/.*SSID: /,\"\");print}');" +
            "[ -n \"$ssid\" ] && lbl=\"$ssid\" || lbl=\"$iface\";" +
            "stats=$(awk -v d=\"$iface:\" '$1==d{print $2,$10}' /proc/net/dev);" +
            "echo \"$lbl|$stats\""
        ]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split("|")
                netLabel = parts[0] || "Offline"
                if (parts.length < 2) return
                var nums = parts[1].trim().split(/\s+/)
                var rx = parseFloat(nums[0]) || 0
                var tx = parseFloat(nums[1]) || 0
                if (_rxPrev >= 0) {
                    rxBps = Math.max(0, (rx - _rxPrev) / 2)
                    txBps = Math.max(0, (tx - _txPrev) / 2)
                }
                _rxPrev = rx
                _txPrev = tx
            }
        }
    }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: netProc.running = true }

    Row {
        anchors.fill: parent

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: netLabel
            font.pixelSize: 12
            color: Colors.onSurface
            elide: Text.ElideRight
            width: parent.width - speedRow.implicitWidth
        }

        Row {
            id: speedRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "↓"; font.pixelSize: 10; color: Colors.primary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: fmt(rxBps)
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    color: Colors.onSurfaceVariant
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "↑"; font.pixelSize: 10; color: Colors.secondary; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: fmt(txBps)
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    color: Colors.onSurfaceVariant
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
