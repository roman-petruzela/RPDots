import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import "../Colors.js" as Colors

Item {
    id: root
    property var caffeine
    property bool polling: false

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    readonly property var adapter: Bluetooth.defaultAdapter

    property bool wifi: false
    property string ssid: ""
    property bool airplane: false
    property bool dnd: false
    property bool night: false
    property string power: ""
    property string busyKey: ""
    signal requestClose()

    implicitHeight: grid.implicitHeight

    onPollingChanged: if (polling) refresh()
    function refresh() { stateProc.running = false; stateProc.running = true }

    Process {
        id: stateProc
        command: ["bash", "-c", `
            echo "wifi=$(nmcli radio wifi 2>/dev/null)"
            echo "ssid=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2 == "802-11-wireless" { print $1; exit }')"
            rfkill list 2>/dev/null | grep -q 'Soft blocked: no' && echo air=off || echo air=on
            echo "dnd=$(rp-settings get notify.dnd)"
            echo "night=$(rp-settings get nightlight.enabled)"
            echo "power=$(rp-power status 2>/dev/null | awk '/^režim:/ { print $2 }')"
        `]
        environment: ({ PATH: root.bin + ":" + Quickshell.env("PATH") })
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {}
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) v[l.slice(0, i)] = l.slice(i + 1) }
                root.wifi = v.wifi === "enabled"
                root.ssid = v.ssid || ""
                root.airplane = v.air === "on"
                root.dnd = v.dnd === "true"
                root.night = v.night === "true"
                root.power = v.power || ""
                root.busyKey = ""
            }
        }
    }

    Process {
        id: action
        onExited: root.refresh()
    }
    function run(key, cmd) {
        root.busyKey = key
        action.command = cmd
        action.running = true
    }

    readonly property var powerLabels: ({ battery: "Battery", balanced: "Balanced", gaming: "Gaming", turbo: "Turbo" })

    Grid {
        id: grid
        width: parent.width
        columns: 4
        spacing: 8
        readonly property real cellW: (width - spacing * 3) / 4

        DashTile {
            width: grid.cellW
            icon: root.wifi ? "\u{f05a9}" : "\u{f05aa}"
            label: root.wifi ? (root.ssid || "Wi-Fi") : "Wi-Fi off"
            active: root.wifi
            busy: root.busyKey === "wifi"
            onClicked: root.run("wifi", [root.bin + "rp-net", "wifi", root.wifi ? "off" : "on"])
        }
        DashTile {
            width: grid.cellW
            readonly property bool on: root.adapter ? root.adapter.enabled : false
            icon: on ? "\u{f00af}" : "\u{f00b2}"
            label: "Bluetooth"
            active: on
            visible: true
            onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        }
        DashTile {
            width: grid.cellW
            icon: root.dnd ? "\u{f009b}" : "\u{f009a}"
            label: "Silent"
            active: root.dnd
            busy: root.busyKey === "dnd"
            onClicked: root.run("dnd", [root.bin + "rp-settings", "set", "notify.dnd", root.dnd ? "false" : "true"])
        }
        DashTile {
            width: grid.cellW
            icon: "\u{f0594}"
            label: "Night light"
            active: root.night
            busy: root.busyKey === "night"
            onClicked: root.run("night", [root.bin + "rp-settings", "set", "nightlight.enabled", root.night ? "false" : "true"])
        }
        DashTile {
            width: grid.cellW
            icon: "\u{f001d}"
            label: "Airplane"
            active: root.airplane
            busy: root.busyKey === "air"
            onClicked: root.run("air", [root.bin + "rp-net", "airplane", root.airplane ? "off" : "on"])
        }
        DashTile {
            width: grid.cellW
            icon: "\u{f0176}"
            label: "Stay awake"
            active: root.caffeine ? root.caffeine.on : false
            onClicked: if (root.caffeine) root.caffeine.toggle()
        }
        DashTile {
            width: grid.cellW
            icon: root.power === "battery" ? "\u{f032a}" : root.power === "gaming" ? "\u{f02b4}" : "\u{f0f85}"
            label: root.powerLabels[root.power] || "Power"
            active: root.power === "gaming"
            onClicked: Quickshell.execDetached([root.bin + "rp-shell", "power", "open"])
        }
        DashTile {
            width: grid.cellW
            icon: "\u{f0493}"
            label: "Settings"
            onClicked: { root.requestClose(); Quickshell.execDetached([root.bin + "rp-shell", "settings", "open"]) }
        }
    }
}
