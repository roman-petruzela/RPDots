import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property bool installed: true
    readonly property string mode: host.settings["nightlight.mode"]?.value ?? "schedule"

    Process {
        id: checkProc
        running: true
        command: ["sh", "-c", "command -v wlsunset"]
        onExited: code => page.installed = code === 0
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
                visible: !page.installed
                width: parent.width
                height: 92
                Text {
                    id: moon
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    text: "󰖔"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 30
                    color: Colors.tertiary
                }
                Column {
                    anchors { left: moon.right; leftMargin: 18; right: installBtn.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel { text: "wlsunset isn't installed"; font.weight: Font.DemiBold }
                    SHint { width: parent.width; text: "niri has no night light of its own; wlsunset does it through the gamma-control protocol." }
                }
                SButton {
                    id: installBtn
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    icon: "󰇚"; text: "Install"
                    busy: page.host.job.running
                    onClicked: page.host.job.start("Installing wlsunset", ["rp-sys", "install", "wlsunset"],
                        ["kitty", "--hold", "-e", "sudo", "pacman", "-S", "wlsunset"],
                        code => { checkProc.running = true; if (code === 0) page.host.run(["rp-settings", "nightlight"]) })
                }
            }

            Repeater {
                model: [
                    { title: "NIGHT LIGHT", rows: [
                        { key: "nightlight.enabled", label: "Night light", hint: "Shift colors to warm in the evening — easier on the eyes and on sleep." },
                        { key: "nightlight.temp", label: "Warmth at night", hint: "Lower is warmer. Daytime stays at 6500 K.", suffix: " K", step: 100 },
                        { key: "nightlight.mode", label: "When", labels: ["Schedule", "Sunset to sunrise", "Always"] },
                    ]},
                    { title: page.mode === "sun" ? "LOCATION" : page.mode === "schedule" ? "SCHEDULE" : "", rows:
                        page.mode === "sun" ? [
                            { key: "nightlight.lat", label: "Latitude", hint: "Sunset and sunrise are computed from this; no location service is used." },
                            { key: "nightlight.lon", label: "Longitude" },
                        ] : page.mode === "schedule" ? [
                            { key: "nightlight.start", label: "Turn on at", hint: "24-hour time, e.g. 21:00. Fades over 30 minutes." },
                            { key: "nightlight.end", label: "Turn off at" },
                        ] : [] },
                ]
                Column {
                    required property var modelData
                    width: col.width
                    spacing: 2
                    SHeading { visible: modelData.title !== ""; text: modelData.title }
                    Repeater {
                        model: modelData.rows
                        delegate: page.host.rowDelegate
                    }
                }
            }
        }
    }
}
