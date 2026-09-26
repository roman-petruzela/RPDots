import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Bluetooth přímo přes Quickshell.Bluetooth (BlueZ na D-Bus): zapnutí,
// hledání, viditelnost, spárovaná zařízení (připojit, odpojit, důvěřovat,
// zapomenout, baterie) a nová zařízení k spárování. Žádný skript — BlueZ
// posílá změny sám, stránka je tak pořád aktuální.
Item {
    id: page
    required property var host

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Nová zařízení: jen s rozumným jménem (bez jména je to většinou šum okolí)
    readonly property var found: devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "")
        .sort((a, b) => a.name.localeCompare(b.name))

    // Hledání se po odchodu ze stránky zastaví — běžící scan žere baterii
    Component.onDestruction: if (adapter && adapter.discovering) adapter.discovering = false

    function deviceIcon(d) {
        const i = d.icon ?? ""
        if (/headset|headphone/.test(i)) return "󰋋"
        if (/audio|speaker/.test(i)) return "󰓃"
        if (/gaming|joystick/.test(i)) return "󰊴"
        if (/mouse/.test(i)) return "󰍽"
        if (/keyboard/.test(i)) return "󰌌"
        if (/phone/.test(i)) return "󰄜"
        if (/computer/.test(i)) return "󰌢"
        if (/watch/.test(i)) return "󰖉"
        return "󰂯"
    }

    function stateText(d) {
        if (d.pairing) return "Pairing…"
        switch (d.state) {
        case BluetoothDeviceState.Connecting: return "Connecting…"
        case BluetoothDeviceState.Disconnecting: return "Disconnecting…"
        case BluetoothDeviceState.Connected: return "Connected"
        }
        return d.paired ? "Paired" : "Not paired"
    }

    // Řádek zařízení
    component DeviceRow: Rectangle {
        id: dr
        property var dev
        property bool isPaired: true
        readonly property bool busy: dev.pairing || dev.state === BluetoothDeviceState.Connecting
                                     || dev.state === BluetoothDeviceState.Disconnecting
        width: parent ? parent.width : 0
        height: 56
        radius: 12
        color: dev.connected ? Qt.alpha(Colors.primary, 0.14)
            : drHover.hovered ? Qt.alpha(Colors.onSurface, 0.04) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        HoverHandler { id: drHover }

        Text {
            id: drIcon
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            width: 20
            horizontalAlignment: Text.AlignHCenter
            text: page.deviceIcon(dr.dev)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: dr.dev.connected ? Colors.primary : Colors.onSurfaceVariant
        }
        Column {
            anchors { left: drIcon.right; leftMargin: 12; right: drRight.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 2
            SLabel { width: parent.width; elide: Text.ElideRight; text: dr.dev.name; font.weight: dr.dev.connected ? Font.Medium : Font.Normal }
            SHint {
                width: parent.width
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                text: page.stateText(dr.dev)
                    + (dr.dev.batteryAvailable ? "  ·  󰁹 " + Math.round(dr.dev.battery * 100) + "%" : "")
                    + (dr.isPaired && !dr.dev.trusted ? "  ·  not trusted" : "")
                    + "  ·  " + dr.dev.address
            }
        }
        Row {
            id: drRight
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
            SSpinner { anchors.verticalCenter: parent.verticalCenter; running: dr.busy }
            SButton {
                visible: dr.isPaired
                anchors.verticalCenter: parent.verticalCenter
                width: 128
                icon: dr.dev.connected ? "󰂲" : "󰂱"
                text: dr.dev.connected ? "Disconnect" : "Connect"
                busy: dr.busy
                onClicked: dr.dev.connected ? dr.dev.disconnect() : dr.dev.connect()
            }
            // Důvěryhodné zařízení se po zapnutí připojí samo
            SButton {
                visible: dr.isPaired
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                icon: dr.dev.trusted ? "󰒘" : "󰒙"
                text: ""
                onClicked: dr.dev.trusted = !dr.dev.trusted
            }
            SButton {
                visible: dr.isPaired
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                danger: true
                icon: "󰆴"; text: ""
                onClicked: dr.dev.forget()
            }
            SButton {
                visible: !dr.isPaired
                anchors.verticalCenter: parent.verticalCenter
                width: 128
                icon: dr.dev.pairing ? "󰜺" : "󰌘"
                text: dr.dev.pairing ? "Cancel" : "Pair"
                onClicked: dr.dev.pairing ? dr.dev.cancelPair() : dr.dev.pair()
            }
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
                    id: btIcon
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    width: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: page.adapter?.enabled ? "󰂯" : "󰂲"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 32
                    color: page.adapter?.enabled ? Colors.primary : Colors.onSurfaceVariant
                }
                Column {
                    anchors { left: btIcon.right; leftMargin: 18; right: btToggle.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel {
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        text: !page.adapter ? "No Bluetooth adapter"
                            : !page.adapter.enabled ? "Bluetooth is off"
                            : page.paired.filter(d => d.connected).length + " connected"
                    }
                    SHint {
                        width: parent.width
                        text: !page.adapter ? "Blocked by airplane mode, or bluetooth.service isn't running."
                            : "Visible to others as “" + page.adapter.name + "”"
                              + (page.adapter.discoverable ? " (discoverable now)" : "")
                    }
                }
                SToggle {
                    id: btToggle
                    visible: page.adapter !== null
                    anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                    checked: page.adapter?.enabled ?? false
                    onToggled: v => page.adapter.enabled = v
                }
            }

            Column {
                width: parent.width
                visible: page.adapter?.enabled ?? false
                spacing: 2

                SHeading { text: "MY DEVICES" }
                SHint {
                    visible: page.paired.length === 0
                    leftPadding: 14; bottomPadding: 6
                    text: "No paired devices yet."
                }
                Repeater {
                    model: page.paired
                    DeviceRow { required property var modelData; dev: modelData }
                }

                Item {
                    width: parent.width
                    height: 50
                    SHeading { anchors.verticalCenter: parent.verticalCenter; topPadding: 0; bottomPadding: 0; text: "ADD A DEVICE" }
                    Row {
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        SSpinner { anchors.verticalCenter: parent.verticalCenter; running: page.adapter?.discovering ?? false }
                        SButton {
                            icon: page.adapter?.discovering ? "󰜺" : "󰍉"
                            text: page.adapter?.discovering ? "Stop" : "Search"
                            onClicked: page.adapter.discovering = !page.adapter.discovering
                        }
                    }
                }
                SHint {
                    visible: page.found.length === 0
                    leftPadding: 14; bottomPadding: 6
                    text: page.adapter?.discovering ? "Looking for devices… Put yours into pairing mode."
                        : "Press Search and put the device into pairing mode."
                }
                Repeater {
                    model: page.found
                    DeviceRow { required property var modelData; dev: modelData; isPaired: false }
                }

                SHeading { text: "OPTIONS" }
                SRow {
                    label: "Discoverable"
                    hint: "Let other devices find this computer (turns itself off after "
                        + (page.adapter?.discoverableTimeout ?? 0) + " s)."
                    SToggle {
                        checked: page.adapter?.discoverable ?? false
                        onToggled: v => page.adapter.discoverable = v
                    }
                }
                SRow {
                    label: "Blueman"
                    hint: "File transfer, network sharing and the other extras."
                    SButton { icon: "󰏌"; text: "Open"; onClicked: Quickshell.execDetached(["blueman-manager"]) }
                }
            }
        }
    }
}
