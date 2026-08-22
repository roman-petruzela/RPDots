import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: netRow.implicitWidth + 10
    implicitHeight: parent ? parent.height : 40

    property string iface:   ""
    property string ip:      ""
    property bool   wifi:    false
    property string ssid:    ""
    property bool   connected: false
    property string vpnIface: ""
    property string vpnName:  ""
    property bool   hasVpn:   false
    property real   rxRate:   0
    property real   txRate:   0
    property real   rxPrev:   0
    property real   txPrev:   0

    property bool dropOpen: false
    property var  screen: null
    property real popupLeftMargin: 4   // set from Bar.qml: rightSection.x + barNet.x

    // ── Network info (5 s) ────────────────────────────────────────
    Process {
        id: netProc
        command: ["bash", "-c",
            "iface=$(ip route show default 2>/dev/null | awk '/default/{print $5;exit}');" +
            "[ -z \"$iface\" ] && echo 'offline|||' && exit;" +
            "ip4=$(ip -4 addr show \"$iface\" 2>/dev/null | awk '/inet /{split($2,a,\"/\");print a[1];exit}');" +
            "ssid=$(iw dev \"$iface\" link 2>/dev/null | awk '/SSID:/{sub(/.*SSID: /,\"\");print;exit}');" +
            "wifi=eth; [ -n \"$ssid\" ] && wifi=wifi;" +
            "vpni=$(ip link show 2>/dev/null | grep -oE '(tun|wg|proton)[0-9]+' | head -1);" +
            "vpnn=$vpni;" +
            "echo \"$iface|$ip4|$wifi|$ssid|$vpni|$vpnn\""
        ]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|")
                root.iface    = p[0] || ""
                root.ip       = p[1] || ""
                root.wifi     = (p[2] || "") === "wifi"
                root.ssid     = p[3] || ""
                root.vpnIface = p[4] || ""
                root.vpnName  = p[5] || p[4] || ""
                root.hasVpn   = root.vpnIface !== ""
                root.connected = root.iface !== "" && root.iface !== "offline"
            }
        }
    }

    // ── Bandwidth (2 s) ───────────────────────────────────────────
    Process {
        id: bwProc
        command: ["bash", "-c",
            "iface=$(ip route show default 2>/dev/null | awk '/default/{print $5;exit}');" +
            "[ -z \"$iface\" ] && echo '0 0' && exit;" +
            "awk -v dev=\"$iface:\" '$1==dev{print $2,$10}' /proc/net/dev"
        ]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split(/\s+/)
                var rx = parseFloat(p[0]) || 0
                var tx = parseFloat(p[1]) || 0
                if (root.rxPrev > 0) {
                    root.rxRate = Math.max(0, rx - root.rxPrev) / 2
                    root.txRate = Math.max(0, tx - root.txPrev) / 2
                }
                root.rxPrev = rx
                root.txPrev = tx
            }
        }
    }

    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: { netProc.running = false; netProc.running = true }
    }
    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: false
        onTriggered: { bwProc.running = false; bwProc.running = true }
    }

    function fmtRate(bps) {
        if (bps < 1024)    return Math.round(bps) + "B"
        if (bps < 1048576) return (bps / 1024).toFixed(0) + "K"
        return (bps / 1048576).toFixed(1) + "M"
    }

    // ── Bar row ───────────────────────────────────────────────────
    Row {
        id: netRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 5

        // VPN chip
        Rectangle {
            visible: root.hasVpn
            height: 18
            width: vpnLbl.implicitWidth + 10
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Qt.color(Colors.tertiary).r, Qt.color(Colors.tertiary).g, Qt.color(Colors.tertiary).b, 0.15)
            border.color: Qt.rgba(Qt.color(Colors.tertiary).r, Qt.color(Colors.tertiary).g, Qt.color(Colors.tertiary).b, 0.45)
            border.width: 1
            Text {
                id: vpnLbl
                anchors.centerIn: parent
                text: " " + (root.vpnName.length > 10 ? root.vpnName.slice(0,10) + "…" : root.vpnName)
                font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                color: Colors.tertiary
            }
        }

        // Connection icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !root.connected ? "󰤬" : root.wifi ? "" : "󰌗"
            font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
            color: root.connected
                ? Colors.primary
                : Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.3)
        }

        // Download
        Row {
            visible: root.connected
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.5)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmtRate(root.rxRate)
                font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.75)
            }
        }

        // Upload
        Row {
            visible: root.connected
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.5)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmtRate(root.txRate)
                font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.75)
            }
        }
    }

    // ── Click toggle ──────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dropOpen = !root.dropOpen
    }

    // ── Dropdown as overlay PanelWindow (escapes 40px bar clip) ───
    PanelWindow {
        id: netDropWin
        visible: root.dropOpen
        color: "transparent"
        screen: root.screen

        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; left: true }
        margins.top: 42
        margins.left: root.popupLeftMargin

        implicitWidth:  netCard.implicitWidth
        implicitHeight: netCard.implicitHeight

        Rectangle {
            id: netCard
            anchors.fill: parent
            implicitWidth:  dropCol.implicitWidth  + 24
            implicitHeight: dropCol.implicitHeight + 20
            radius: 10
            color: Qt.rgba(Qt.color(Colors.surfaceContainerHigh).r,
                           Qt.color(Colors.surfaceContainerHigh).g,
                           Qt.color(Colors.surfaceContainerHigh).b, 0.97)
            border.color: Qt.rgba(Qt.color(Colors.outlineVariant).r,
                                  Qt.color(Colors.outlineVariant).g,
                                  Qt.color(Colors.outlineVariant).b, 0.55)
            border.width: 1

            // Close dropdown when clicking inside card area
            MouseArea {
                anchors.fill: parent
                onClicked: root.dropOpen = false
            }

            Column {
                id: dropCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                Row {
                    spacing: 8
                    Text { text: "\uf316"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                        color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.5) }
                    Text { text: root.iface || "—"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; color: Colors.onSurface }
                }
                Row {
                    spacing: 8
                    Text { text: "\uf0ac"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                        color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.5) }
                    Text { text: root.ip || "—"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; color: Colors.onSurface }
                }
                Row {
                    visible: root.wifi && root.ssid !== ""
                    spacing: 8
                    Text { text: "\uf1eb"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; color: Colors.primary }
                    Text { text: root.ssid; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; color: Colors.onSurface }
                }
                Row {
                    visible: root.hasVpn
                    spacing: 8
                    Text { text: "\uf09e"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; color: Colors.tertiary }
                    Text { text: root.vpnName || "VPN"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; color: Colors.tertiary }
                }
            }
        }
    }
}
