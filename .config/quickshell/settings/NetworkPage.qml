import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property var info: null
    property var wifi: null
    property var publicIp: null
    property bool publicIpLoading: false
    property var speed: ({})
    property string askPassword: ""
    property string connecting: ""
    property string connectError: ""

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/rp-net"

    function reload() {
        detailsProc.running = false
        detailsProc.running = true
        statusProc.running = false
        statusProc.running = true
    }

    function net(args) {
        actionProc.running = false
        actionProc.command = [bin].concat(args)
        actionProc.running = true
    }

    function connect(ssid, password) {
        connecting = ssid
        connectError = ""
        askPassword = ""
        connectProc.command = [bin, "connect", ssid]
        connectProc.stdinEnabled = true
        connectProc.running = true
        if (password !== "") connectProc.write(password + "\n")
        connectProc.stdinEnabled = false
    }

    Component.onCompleted: reload()

    Process {
        id: detailsProc
        command: [page.bin, "details"]
        stdout: StdioCollector {
            onStreamFinished: { try { page.info = JSON.parse(text) } catch (e) { page.host.showError("rp-net details failed") } }
        }
    }
    Process {
        id: statusProc
        command: [page.bin, "status"]
        stdout: StdioCollector {
            onStreamFinished: { try { page.wifi = JSON.parse(text) } catch (e) {} }
        }
    }
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: if (/^Error/m.test(text)) page.host.showError(text.trim().split("\n").pop())
        }
        onExited: refresh.restart()
    }
    Process {
        id: connectProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.connecting = ""
                try {
                    const r = JSON.parse(text)
                    if (!r.ok) page.connectError = r.ssid + ": " + r.message
                } catch (e) {}
                page.reload()
            }
        }
    }
    Process {
        id: ipProc
        command: [page.bin, "publicip"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.publicIpLoading = false
                try { page.publicIp = JSON.parse(text) } catch (e) { page.publicIp = { error: "failed" } }
            }
        }
    }
    Process {
        id: speedProc
        command: [page.bin, "speedtest"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const r = JSON.parse(line)
                    const s = Object.assign({}, page.speed, { phase: r.phase })
                    if (r.ms !== undefined) s.latency = r.ms
                    if (r.mbps !== undefined) s[r.phase] = r.mbps
                    if (r.message) s.error = r.message
                    page.speed = s
                } catch (e) {}
            }
        }
        onExited: if (page.speed.phase !== "done" && page.speed.phase !== "error") page.speed = Object.assign({}, page.speed, { phase: "error" })
    }

    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: refresh.restart() }
    }
    Timer { id: refresh; interval: 400; onTriggered: page.reload() }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: statusProc.running = true }

    readonly property var primary: info ? (info.interfaces.find(i => i.device === info.routeDevice) ?? null) : null
    readonly property var activeVpn: info ? info.vpn.filter(v => v.active) : []

    function typeName(t) {
        return ({ ethernet: "Ethernet", "802-3-ethernet": "Ethernet", wifi: "Wi-Fi", "802-11-wireless": "Wi-Fi",
                  wireguard: "WireGuard", vpn: "VPN", gsm: "Mobile", bt: "Bluetooth" })[t] ?? t
    }

    function signalIcon(s) {
        return s >= 75 ? "󰤨" : s >= 50 ? "󰤥" : s >= 25 ? "󰤢" : "󰤟"
    }

    component Field: Item {
        id: fld
        property string label
        property string value
        visible: value !== ""
        width: parent ? parent.width : 0
        height: visible ? Math.max(24, fv.implicitHeight + 6) : 0
        SHint { id: fk; anchors.verticalCenter: parent.verticalCenter; width: 90; text: fld.label; wrapMode: Text.NoWrap }
        SMono {
            id: fv
            anchors { left: fk.right; right: parent.right; verticalCenter: parent.verticalCenter }
            text: fld.value
            color: Colors.onSurface
            wrapMode: Text.WrapAnywhere
        }
    }

    component Metric: Column {
        id: mt
        property string label
        property string value
        property string unit
        property bool active: false
        width: parent ? (parent.width - 24) / 3 : 0
        spacing: 4
        Row {
            spacing: 6
            SHint { text: mt.label; wrapMode: Text.NoWrap; anchors.verticalCenter: parent.verticalCenter }
            SSpinner { size: 12; running: mt.active; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            spacing: 4
            SLabel { text: mt.value; font.pixelSize: 24; font.weight: Font.DemiBold; anchors.baseline: unitText.baseline }
            SHint { id: unitText; text: mt.unit; wrapMode: Text.NoWrap }
        }
    }

    SWheel { flick: flick }
    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}

        Column {
            id: col
            width: flick.width - 12
            spacing: 2
            topPadding: 8

            SCard {
                width: parent.width
                height: 96

                Text {
                    id: netIcon
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    width: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: page.info?.airplane ? "󰀝"
                        : !page.primary ? "󰤮"
                        : page.primary.type === "wifi" ? "󰤨" : "󰈀"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 32
                    color: page.primary ? Colors.primary : Colors.onSurfaceVariant
                }
                Column {
                    anchors { left: netIcon.right; leftMargin: 18; right: airplane.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        text: page.info?.airplane ? "Airplane mode"
                            : !page.primary ? "Not connected"
                            : page.typeName(page.primary.type) + " · " + page.primary.connection
                    }
                    SHint {
                        width: parent.width
                        text: page.primary
                            ? (page.primary.ipv4[0] ?? "") + "  ·  " + page.info.hostname
                              + (page.activeVpn.length ? "  ·  VPN " + page.activeVpn.map(v => v.name).join(", ") : "")
                            : page.info?.hostname ?? ""
                    }
                }
                Row {
                    id: airplane
                    anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    SHint { anchors.verticalCenter: parent.verticalCenter; text: "󰀝  Airplane"; wrapMode: Text.NoWrap }
                    SToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: page.info?.airplane ?? false
                        onToggled: v => page.net(["airplane", v ? "on" : "off"])
                    }
                }
            }

            Item { width: 1; height: 10 }

            SCard {
                width: parent.width
                height: speedCol.implicitHeight + 36
                Column {
                    id: speedCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 14
                    Item {
                        width: parent.width
                        height: 34
                        SLabel { anchors.verticalCenter: parent.verticalCenter; text: "Speed & public address"; font.weight: Font.DemiBold }
                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            SButton {
                                icon: "󰩠"; text: "Public IP"
                                busy: page.publicIpLoading
                                onClicked: { page.publicIpLoading = true; ipProc.running = true }
                            }
                            SButton {
                                icon: "󰓅"; text: speedProc.running ? "Testing…" : "Speed test"
                                busy: speedProc.running
                                onClicked: { page.speed = { phase: "latency" }; speedProc.running = true }
                            }
                        }
                    }
                    Row {
                        visible: page.speed.phase !== undefined
                        width: parent.width
                        spacing: 12
                        Metric {
                            label: "Latency"; unit: "ms"
                            value: page.speed.latency !== undefined ? Math.round(page.speed.latency) : "–"
                            active: page.speed.phase === "latency"
                        }
                        Metric {
                            label: "Download"; unit: "Mbit/s"
                            value: page.speed.download !== undefined ? page.speed.download : "–"
                            active: page.speed.phase === "download" && page.speed.download === undefined
                        }
                        Metric {
                            label: "Upload"; unit: "Mbit/s"
                            value: page.speed.upload !== undefined ? page.speed.upload : "–"
                            active: page.speed.phase === "upload" && page.speed.upload === undefined
                        }
                    }
                    SHint {
                        visible: page.speed.phase !== undefined || page.publicIp !== null
                        width: parent.width
                        color: page.speed.error ? Colors.errorColor : Colors.onSurfaceVariant
                        text: [
                            page.speed.error ?? "",
                            page.publicIp ? (page.publicIp.error ? "Public IP: offline"
                                : "Public IP " + page.publicIp.ip + " · " + page.publicIp.country
                                  + " · via Cloudflare " + page.publicIp.datacenter) : "",
                            page.speed.phase !== undefined ? "Measured against speed.cloudflare.com (25 MB down, 10 MB up), through the VPN if it's on." : "",
                        ].filter(t => t !== "").join("\n")
                    }
                }
            }

            SHeading { text: "WI-FI" }
            SRow {
                label: "Wi-Fi"
                hint: !page.wifi ? "Scanning…"
                    : page.wifi.wifiEnabled ? (page.wifi.networks.length + " networks around") : "Off"
                Row {
                    spacing: 10
                    SButton {
                        visible: page.wifi?.wifiEnabled ?? false
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰑓"; text: ""
                        onClicked: page.net(["rescan"])
                    }
                    SSpinner { anchors.verticalCenter: parent.verticalCenter; running: !page.wifi }
                    SToggle {
                        visible: page.wifi !== null
                        anchors.verticalCenter: parent.verticalCenter
                        checked: page.wifi?.wifiEnabled ?? false
                        onToggled: v => page.net(["wifi", v ? "on" : "off"])
                    }
                }
            }
            SHint {
                visible: page.connectError !== ""
                leftPadding: 14; bottomPadding: 4
                color: Colors.errorColor
                text: page.connectError
            }
            Repeater {
                model: page.wifi?.wifiEnabled ? page.wifi.networks : []
                Rectangle {
                    id: nw
                    required property var modelData
                    readonly property bool asking: page.askPassword === modelData.ssid
                    width: col.width
                    height: asking ? 96 : 48
                    radius: 12
                    color: modelData.active ? Qt.alpha(Colors.primary, 0.14)
                        : nwHover.hovered || asking ? Qt.alpha(Colors.onSurface, 0.04) : "transparent"
                    HoverHandler { id: nwHover }

                    Item {
                        id: nwHead
                        width: parent.width
                        height: 48
                        Text {
                            id: sigIcon
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            width: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: page.signalIcon(nw.modelData.signal)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: nw.modelData.active ? Colors.primary : Colors.onSurfaceVariant
                        }
                        SLabel {
                            anchors { left: sigIcon.right; leftMargin: 12; right: nwRight.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: nw.modelData.ssid
                            font.weight: nw.modelData.active ? Font.Medium : Font.Normal
                        }
                        Row {
                            id: nwRight
                            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            SSpinner { anchors.verticalCenter: parent.verticalCenter; running: page.connecting === nw.modelData.ssid }
                            SHint {
                                anchors.verticalCenter: parent.verticalCenter
                                wrapMode: Text.NoWrap
                                text: (nw.modelData.saved ? "saved · " : "") + nw.modelData.signal + "%"
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                text: nw.modelData.secured ? "󰌾" : ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Colors.onSurfaceVariant
                            }
                            SButton {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: nw.modelData.active
                                width: 124
                                icon: "󰅖"; text: "Disconnect"
                                onClicked: page.net(["disconnect"])
                            }
                            SButton {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !nw.modelData.active
                                width: 124
                                icon: "󰖩"; text: "Connect"
                                busy: page.connecting !== ""
                                onClicked: {
                                    if (nw.modelData.saved || !nw.modelData.secured) page.connect(nw.modelData.ssid, "")
                                    else page.askPassword = nw.asking ? "" : nw.modelData.ssid
                                }
                            }
                        }
                    }
                    Row {
                        visible: nw.asking
                        anchors { left: parent.left; leftMargin: 46; top: nwHead.bottom }
                        spacing: 8
                        STextBox {
                            id: pw
                            width: 260
                            placeholder: "Password"
                            commitOnBlur: false
                            password: true
                            onCommitted: v => { if (v !== "") page.connect(nw.modelData.ssid, v); pw.text = "" }
                        }
                        SButton { icon: "󰖩"; text: "Join"; onClicked: pw.committed(pw.text) }
                    }
                }
            }

            SHeading { text: "VPN" }
            SHint {
                visible: (page.info?.vpn.length ?? 0) === 0
                leftPadding: 14; bottomPadding: 6
                text: "No VPN connections in NetworkManager."
            }
            Repeater {
                model: page.info?.vpn ?? []
                SRow {
                    required property var modelData
                    icon: "󰖂"
                    label: modelData.name
                    hint: page.typeName(modelData.type) + (modelData.active ? " · connected on " + modelData.device : "")
                    SToggle {
                        checked: modelData.active
                        onToggled: v => page.net([v ? "up" : "down", modelData.name])
                    }
                }
            }
            SRow {
                label: "Proton VPN"
                hint: "Servers, kill switch and Secure Core live in the Proton app."
                SButton { icon: "󰏌"; text: "Open"; onClicked: Quickshell.execDetached(["protonvpn-app"]) }
            }

            SHeading { text: "SAVED CONNECTIONS" }
            Repeater {
                model: page.info?.connections ?? []
                SRow {
                    required property var modelData
                    icon: /wireless/.test(modelData.type) ? "󰖩" : "󰈀"
                    label: modelData.name
                    hint: page.typeName(modelData.type) + (modelData.active ? " · active" : "")
                          + (modelData.autoconnect ? " · connects automatically" : "")
                    Row {
                        spacing: 8
                        SHint { anchors.verticalCenter: parent.verticalCenter; text: "Auto"; wrapMode: Text.NoWrap }
                        SToggle {
                            anchors.verticalCenter: parent.verticalCenter
                            checked: modelData.autoconnect
                            onToggled: v => page.net(["autoconnect", modelData.name, v ? "yes" : "no"])
                        }
                        SButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: modelData.active ? "󰅖" : "󰌘"; text: ""
                            onClicked: page.net([modelData.active ? "down" : "up", modelData.name])
                        }
                        SButton {
                            anchors.verticalCenter: parent.verticalCenter
                            danger: true
                            icon: "󰆴"; text: ""
                            onClicked: page.net(["forget", modelData.name])
                        }
                    }
                }
            }

            SHeading { text: "INTERFACES" }
            Flow {
                width: parent.width
                spacing: 12
                Repeater {
                    model: page.info?.interfaces ?? []
                    SCard {
                        id: ifc
                        required property var modelData
                        width: (col.width - 12) / 2
                        height: ifCol.implicitHeight + 36
                        Column {
                            id: ifCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                            spacing: 4
                            Item {
                                width: parent.width
                                height: 26
                                SLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ifc.modelData.device + "  ·  " + page.typeName(ifc.modelData.type)
                                    font.weight: Font.DemiBold
                                }
                                SHint {
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    wrapMode: Text.NoWrap
                                    text: ifc.modelData.state
                                    color: ifc.modelData.state === "connected" ? Colors.primary : Colors.onSurfaceVariant
                                }
                            }
                            Field { label: "IPv4"; value: ifc.modelData.ipv4.join("\n") }
                            Field { label: "Gateway"; value: ifc.modelData.gateway }
                            Field { label: "DNS"; value: ifc.modelData.dns.join(", ") }
                            Field { label: "IPv6"; value: ifc.modelData.ipv6.join("\n") }
                            Field { label: "MAC"; value: ifc.modelData.mac }
                            Field { label: "Link"; value: ifc.modelData.speed ? ifc.modelData.speed + " Mbit/s" : "" }
                            Field {
                                label: "Wi-Fi"
                                value: ifc.modelData.wifi
                                    ? ifc.modelData.wifi.band + " (" + ifc.modelData.wifi.freq + " MHz) · "
                                      + ifc.modelData.wifi.dbm + " dBm · " + ifc.modelData.wifi.tx + " Mbit/s"
                                    : ""
                            }
                        }
                    }
                }
            }

            SRow {
                label: "Advanced connection settings"
                hint: "Static IP, DNS, proxies, 802.1X — NetworkManager's own editor."
                SButton { icon: "󰏌"; text: "Open editor"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
            }
        }
    }
}
