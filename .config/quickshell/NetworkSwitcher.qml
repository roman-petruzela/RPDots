import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Flyout {
    id: root

    heading: "Network"
    cardWidth: 400

    property var data: ({
        networks: [], wifiEnabled: false, wifiDevice: "",
        routeDevice: "", routeIp: "", ethernet: null, wifi: null,
    })
    property string pendingSsid: ""
    property string message: ""
    property bool busy: false

    readonly property var networks: data.networks || []
    readonly property var ethernet: data.ethernet || null
    readonly property var wifi: data.wifi || null

    Process {
        id: statusProc
        command: ["bash", "-c", "$HOME/.local/bin/rp-net status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.data = JSON.parse(text) } catch (e) { /* rozbitý JSON */ }
            }
        }
        function reload() { running = false; running = true }
    }

    Process {
        id: actionProc
        command: ["bash", "-c", "true"]
        onExited: { root.busy = false; statusProc.reload() }
    }

    Process {
        id: connectProc
        command: ["bash", "-c", "true"]
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text)
                    root.message = r.ok ? "" : (r.message || "connection failed")
                } catch (e) {
                    root.message = ""
                }
            }
        }
        onExited: { root.busy = false; statusProc.reload() }
    }

    Process { id: editorProc; command: ["nm-connection-editor"] }

    function run(args) {
        root.busy = true
        actionProc.running = false
        actionProc.command = ["bash", "-c", "$HOME/.local/bin/rp-net " + args]
        actionProc.running = true
    }

    function connect(ssid, password) {
        root.busy = true
        root.message = ""
        connectProc.running = false
        connectProc.command = ["bash", "-c",
            "$HOME/.local/bin/rp-net connect " + JSON.stringify(ssid)]
        connectProc.running = true
        if (password !== "") connectProc.write(password + "\n")
        connectProc.stdinEnabled = false
    }

    function activate(net) {
        if (net.active) return
        if (net.secured && !net.saved) {
            root.pendingSsid = (root.pendingSsid === net.ssid) ? "" : net.ssid
            root.message = ""
            return
        }
        root.pendingSsid = ""
        connect(net.ssid, "")
    }

    function signalIcon(signal) {
        if (signal >= 80) return "󰤨"
        if (signal >= 60) return "󰤥"
        if (signal >= 40) return "󰤢"
        if (signal >= 20) return "󰤟"
        return "󰤯"
    }

    onOpened: {
        root.pendingSsid = ""
        root.message = ""
        statusProc.reload()
        run("rescan")
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        onTriggered: statusProc.reload()
    }

    Rectangle {
        width: root.cardWidth - 32
        height: 50
        radius: 12
        color: Colors.surfaceContainerHigh

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.data.routeDevice === (root.wifi ? root.wifi.device : "")
                    ? "" : "󰌘"
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font"
                color: root.data.routeIp ? Colors.primary : Colors.outline
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 42
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: {
                        if (!root.data.routeDevice) return "Offline"
                        const dev = root.data.routeDevice
                        if (root.wifi && dev === root.wifi.device)
                            return root.wifi.connection || "Wi-Fi"
                        if (root.ethernet && dev === root.ethernet.device)
                            return root.ethernet.connection || "Ethernet"
                        return dev
                    }
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.onSurface
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.data.routeIp
                        ? root.data.routeDevice + " · " + root.data.routeIp
                        : "no default route"
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.outline
                }
            }
        }
    }

    Item { width: 1; height: 10 }

    Row {
        width: root.cardWidth - 32
        height: 24
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Wi-Fi"
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.onSurfaceVariant
        }

        Item { width: parent.width - 150; height: 1 }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.busy ? "working…" : (root.data.wifiEnabled ? "on" : "off")
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.outline
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 22; radius: 11
            color: root.data.wifiEnabled
                ? Qt.rgba(Qt.color(Colors.primary).r,
                          Qt.color(Colors.primary).g,
                          Qt.color(Colors.primary).b, 0.45)
                : Colors.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                width: 16; height: 16; radius: 8
                y: 3
                x: root.data.wifiEnabled ? parent.width - width - 3 : 3
                color: root.data.wifiEnabled ? Colors.primary : Colors.outline
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.run(root.data.wifiEnabled ? "wifi off" : "wifi on")
            }
        }
    }

    Item { width: 1; height: 6 }

    Column {
        width: root.cardWidth - 32
        spacing: 0
        visible: root.data.wifiEnabled

        Repeater {
            model: root.networks.slice(0, 7)

            Column {
                required property var modelData
                width: parent.width

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 10

                    color: modelData.active
                        ? Qt.rgba(Qt.color(Colors.primary).r,
                                  Qt.color(Colors.primary).g,
                                  Qt.color(Colors.primary).b, 0.18)
                        : netHover.containsMouse
                            ? Colors.surfaceContainerHigh
                            : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.signalIcon(modelData.signal)
                            font.pixelSize: 15
                            font.family: "JetBrainsMono Nerd Font"
                            color: modelData.active ? Colors.primary : Colors.onSurfaceVariant
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 100
                            text: modelData.ssid
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            font.weight: modelData.active ? Font.Medium : Font.Normal
                            color: modelData.active ? Colors.onSurface : Colors.onSurfaceVariant
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.secured ? "󰌾" : ""
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                            color: Colors.outline
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.active ? "󰄬" : (modelData.saved ? "󰆓" : "")
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                            color: modelData.active ? Colors.primary : Colors.outline
                        }
                    }

                    MouseArea {
                        id: netHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(modelData)
                    }
                }

                Row {
                    width: parent.width
                    height: visible ? 36 : 0
                    visible: root.pendingSsid === modelData.ssid
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 78
                        height: 30
                        radius: 8
                        color: Colors.surfaceContainerHighest
                        border.color: Colors.outlineVariant
                        border.width: 1

                        TextInput {
                            id: pwInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            color: Colors.onSurface
                            selectionColor: Colors.primary
                            focus: root.pendingSsid === modelData.ssid
                            onAccepted: {
                                root.connect(modelData.ssid, text)
                                text = ""
                                root.pendingSsid = ""
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password"
                                visible: pwInput.text === ""
                                font: pwInput.font
                                color: Colors.outline
                            }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70; height: 30; radius: 8
                        color: joinHover.containsMouse
                            ? Qt.rgba(Qt.color(Colors.primary).r,
                                      Qt.color(Colors.primary).g,
                                      Qt.color(Colors.primary).b, 0.18)
                            : Colors.surfaceContainerHigh
                        border.color: Qt.rgba(Qt.color(Colors.primary).r,
                                              Qt.color(Colors.primary).g,
                                              Qt.color(Colors.primary).b, 0.3)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                            color: Colors.onSurfaceVariant
                        }

                        MouseArea {
                            id: joinHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.connect(modelData.ssid, pwInput.text)
                                pwInput.text = ""
                                root.pendingSsid = ""
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        width: root.cardWidth - 32
        text: root.message
        visible: text !== ""
        wrapMode: Text.WordWrap
        topPadding: 6
        font.pixelSize: 11
        font.family: "JetBrainsMono Nerd Font"
        color: Colors.errorColor
    }

    Item { width: 1; height: 10 }
    Divider { width: root.cardWidth - 32 }
    Item { width: 1; height: 10 }

    Row {
        width: root.cardWidth - 32
        spacing: 8

        Repeater {
            model: [
                { icon: "󰑐", label: "Rescan",   action: "rescan" },
                { icon: "󰅖", label: "Disconnect", action: "disconnect" },
                { icon: "󰒓", label: "Settings", action: "editor" },
            ]

            Rectangle {
                required property var modelData

                width: (root.cardWidth - 32 - 16) / 3
                height: 34
                radius: 10
                color: actHover.containsMouse
                    ? Qt.rgba(Qt.color(Colors.primary).r,
                              Qt.color(Colors.primary).g,
                              Qt.color(Colors.primary).b, 0.18)
                    : Colors.surfaceContainerHigh
                border.color: Qt.rgba(Qt.color(Colors.primary).r,
                                      Qt.color(Colors.primary).g,
                                      Qt.color(Colors.primary).b, 0.3)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        color: Colors.primary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        color: Colors.onSurfaceVariant
                    }
                }

                MouseArea {
                    id: actHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.action === "editor") {
                            editorProc.running = true
                            root.visible = false
                        } else {
                            root.run(modelData.action)
                        }
                    }
                }
            }
        }
    }
}
