import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property var fw: null
    property var services: []
    property bool loading: false
    property string pendingService: ""

    function reload() {
        loading = true
        stateProc.running = false
        stateProc.running = true
    }

    function act(title, args) {
        host.job.start(title, ["rp-sys", "fw"].concat(args), [], code => page.reload())
    }

    Component.onCompleted: reload()

    Process {
        id: stateProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "firewall"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.loading = false
                try { page.fw = JSON.parse(text) } catch (e) { page.host.showError("Could not read firewall state") }
                if (page.fw?.responding && page.services.length === 0) svcProc.running = true
            }
        }
    }
    Process {
        id: svcProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "fw-services"]
        stdout: StdioCollector {
            onStreamFinished: { try { page.services = JSON.parse(text) } catch (e) {} }
        }
    }

    readonly property string status: !fw ? "loading"
        : !fw.active ? "stopped"
        : !fw.responding ? "stuck"
        : fw.panic ? "panic" : "ok"

    component TagList: Flow {
        id: tl
        property var items: []
        signal removed(string item)
        width: parent ? parent.width : 0
        spacing: 8
        Repeater {
            model: tl.items
            Rectangle {
                required property var modelData
                width: tagRow.width + 20
                height: 30
                radius: 15
                color: Qt.alpha(Colors.primary, 0.12)
                border.width: 1
                border.color: Qt.alpha(Colors.primary, 0.35)
                Row {
                    id: tagRow
                    anchors.centerIn: parent
                    height: parent.height
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: Colors.onSurface
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: xHover.hovered ? Colors.errorColor : Colors.onSurfaceVariant
                        HoverHandler { id: xHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: tl.removed(modelData) }
                    }
                }
            }
        }
        SHint {
            visible: tl.items.length === 0
            height: 30
            verticalAlignment: Text.AlignVCenter
            text: "None"
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
            spacing: 8
            topPadding: 8

            SCard {
                width: parent.width
                height: 96

                Text {
                    id: shield
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    width: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: page.status === "ok" ? "󰒃" : page.status === "panic" ? "󰦞" : "󰒄"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 34
                    color: page.status === "ok" ? Colors.primary
                        : page.status === "loading" ? Colors.onSurfaceVariant : Colors.errorColor
                }
                Column {
                    anchors { left: shield.right; leftMargin: 18; right: fwActions.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel {
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        text: ({ loading: "Checking firewall…", stopped: "Firewall is off",
                                 stuck: "Firewall is not responding", panic: "Panic mode: all traffic blocked",
                                 ok: "Firewall is on" })[page.status]
                    }
                    SHint {
                        width: parent.width
                        text: page.status === "stuck" ? page.fw.error
                            : page.status === "ok" || page.status === "panic"
                                ? "firewalld · zone " + page.fw.zone
                                  + (page.fw.interfaces.length ? " · " + page.fw.interfaces.join(", ") : "")
                            : page.status === "stopped" ? "firewalld is not running" : ""
                    }
                }
                Row {
                    id: fwActions
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    SSpinner { anchors.verticalCenter: parent.verticalCenter; running: page.loading }
                    SButton {
                        visible: page.status === "stuck"
                        icon: "󰑓"; text: "Restart firewalld"
                        busy: page.host.job.running
                        onClicked: page.act("Restarting firewalld", ["restart"])
                    }
                    SButton {
                        visible: page.status === "stopped"
                        icon: "󰒃"; text: "Turn on"
                        busy: page.host.job.running
                        onClicked: page.act("Starting firewalld", ["start"])
                    }
                    SButton {
                        visible: page.status === "ok" || page.status === "panic"
                        danger: true
                        icon: "󰒄"; text: "Turn off"
                        busy: page.host.job.running
                        onClicked: page.act("Stopping firewalld", ["stop"])
                    }
                    SButton { icon: "󰑓"; text: ""; onClicked: page.reload() }
                }
            }

            SHint {
                visible: page.fw?.ufw ?? false
                width: parent.width
                leftPadding: 14; rightPadding: 14
                color: Colors.tertiary
                text: "ufw is active too — two firewalls fight over the same rules; keep only one enabled."
            }

            Column {
                width: parent.width
                visible: page.status === "ok" || page.status === "panic"
                spacing: 2

                SHeading { text: "PROTECTION" }
                SRow {
                    label: "Panic mode"
                    hint: "Drop all incoming and outgoing traffic immediately."
                    SToggle {
                        checked: page.fw?.panic ?? false
                        onToggled: v => page.act(v ? "Enabling panic mode" : "Disabling panic mode", [v ? "panic-on" : "panic-off"])
                    }
                }

                SHeading { text: "ALLOWED SERVICES" }
                Item {
                    width: parent.width
                    height: svcList.height + 16
                    TagList {
                        id: svcList
                        x: 14; y: 8
                        width: parent.width - 28
                        items: page.fw?.services ?? []
                        onRemoved: s => page.act("Blocking service " + s, ["remove-service", s])
                    }
                }
                SRow {
                    label: "Allow a service"
                    hint: "Predefined firewalld services (ssh, http, kdeconnect…)."
                    Row {
                        spacing: 8
                        SDropdown {
                            options: page.services.filter(s => !(page.fw?.services ?? []).includes(s))
                            current: page.pendingService
                            displayText: page.pendingService || "Choose…"
                            onPicked: v => page.pendingService = v
                        }
                        SButton {
                            icon: "󰐕"; text: "Allow"
                            busy: page.pendingService === "" || page.host.job.running
                            onClicked: { page.act("Allowing service " + page.pendingService, ["add-service", page.pendingService]); page.pendingService = "" }
                        }
                    }
                }

                SHeading { text: "OPEN PORTS" }
                Item {
                    width: parent.width
                    height: portList.height + 16
                    TagList {
                        id: portList
                        x: 14; y: 8
                        width: parent.width - 28
                        items: page.fw?.ports ?? []
                        onRemoved: p => page.act("Closing port " + p, ["remove-port", p])
                    }
                }
                SRow {
                    label: "Open a port"
                    hint: "e.g. 8080/tcp or 27015-27030/udp"
                    Row {
                        spacing: 8
                        STextBox {
                            id: portBox
                            width: 200
                            placeholder: "port/protocol"
                            commitOnBlur: false
                            onCommitted: v => { if (v.trim() !== "") { page.act("Opening port " + v.trim(), ["add-port", v.trim()]); portBox.text = "" } }
                        }
                        SButton {
                            icon: "󰐕"; text: "Open"
                            busy: page.host.job.running
                            onClicked: portBox.committed(portBox.text)
                        }
                    }
                }
            }
        }
    }
}
