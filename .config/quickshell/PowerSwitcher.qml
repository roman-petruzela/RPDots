import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

// Přepínač power režimů — obdoba přepínače zvuku, jen nad rp-power.
// Stav se čte z `rp-power status`, dokud je okno otevřené.
Flyout {
    id: root

    heading: "Power mode"
    cardWidth: 400

    property string mode: "?"
    property string acPower: ""
    property string acpiProfile: ""
    property string governor: ""
    property string wallpaper: ""
    property string gpu: ""

    readonly property var modes: [
        { id: "battery",  icon: "󰁹", label: "Battery",  hint: "CPU powersave, dGPU limited, wallpaper suspended" },
        { id: "balanced", icon: "󰗑", label: "Balanced", hint: "Everyday default" },
        { id: "gaming",   icon: "󰊴", label: "Gaming",   hint: "Full power, dGPU clocks locked" },
    ]

    Process {
        id: applyProc
        // rp-power sahá na sudo helper, proto přes shell s absolutní cestou
        command: ["bash", "-c", "$HOME/.local/bin/rp-power balanced"]
        onExited: statusProc.reload()
    }

    Process {
        id: statusProc
        command: ["bash", "-c", "$HOME/.local/bin/rp-power status"]
        stdout: StdioCollector {
            // rp-power vypisuje česky, okno je anglicky
            readonly property var dict: ({
                "síť": "AC", "baterie": "Battery",
                "uspaná": "suspended", "přehrává se": "playing", "žádná": "none",
                "spí (0 W)": "asleep (0 W)",
            })

            onStreamFinished: {
                // formát: "klíč:   hodnota"
                const field = key => {
                    const line = text.split("\n").find(l => l.startsWith(key))
                    if (!line) return ""
                    const value = line.slice(key.length).replace(":", "").trim()
                    return dict[value] !== undefined ? dict[value] : value
                }
                root.mode        = field("režim") || "?"
                root.acPower     = field("napájení")
                root.acpiProfile = field("ACPI profil")
                root.governor    = field("CPU governor")
                root.wallpaper   = field("video tapeta")
                root.gpu         = field("dGPU")
            }
        }

        function reload() {
            statusProc.running = false
            statusProc.running = true
        }
    }

    function setMode(id) {
        applyProc.running = false
        applyProc.command = ["bash", "-c", "$HOME/.local/bin/rp-power " + id]
        applyProc.running = true
    }

    // Čerstvý stav při otevření, pak průběžně — přepnutí režimu chvíli trvá
    // a dGPU se mění i bez našeho přičinění.
    onOpened: statusProc.reload()

    Timer {
        interval: 3000
        repeat: true
        running: root.visible
        onTriggered: statusProc.reload()
    }

    // ── Režimy ─────────────────────────────────────────────────────────────
    Repeater {
        model: root.modes

        Rectangle {
            required property var modelData

            width: root.cardWidth - 32
            height: 54
            radius: 12

            readonly property bool isActive: modelData.id === root.mode

            color: isActive
                ? Qt.rgba(Qt.color(Colors.primary).r,
                          Qt.color(Colors.primary).g,
                          Qt.color(Colors.primary).b, 0.18)
                : rowHover.containsMouse
                    ? Colors.surfaceContainerHigh
                    : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.icon
                    font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                    color: isActive ? Colors.primary : Colors.onSurfaceVariant
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 62
                    spacing: 2

                    Text {
                        width: parent.width
                        text: modelData.label
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        font.weight: isActive ? Font.Medium : Font.Normal
                        color: isActive ? Colors.onSurface : Colors.onSurfaceVariant
                    }
                    Text {
                        width: parent.width
                        text: modelData.hint
                        elide: Text.ElideRight
                        font.pixelSize: 10
                        font.family: "JetBrainsMono Nerd Font"
                        color: Colors.outline
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰄬"
                    font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.primary
                    opacity: isActive ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Okno zůstává otevřené, ať je vidět, jak se stav dole srovnal.
                onClicked: root.setMode(modelData.id)
            }
        }
    }

    Item { width: 1; height: 8 }
    Divider { width: root.cardWidth - 32 }
    Item { width: 1; height: 10 }

    // ── Stav ───────────────────────────────────────────────────────────────
    Column {
        width: root.cardWidth - 32
        spacing: 6

        Repeater {
            model: [
                { icon: "󰚥", label: "Power",     value: root.acPower },
                { icon: "󰓅", label: "Profile",   value: root.acpiProfile },
                { icon: "󰍛", label: "CPU",       value: root.governor },
                { icon: "󰢮", label: "dGPU",      value: root.gpu },
                { icon: "󰕧", label: "Wallpaper", value: root.wallpaper },
            ]

            Row {
                required property var modelData

                width: parent.width
                spacing: 8
                visible: modelData.value !== ""

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    text: modelData.icon
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.outline
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 68
                    text: modelData.label
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.outline
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 108
                    text: modelData.value
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.onSurfaceVariant
                }
            }
        }
    }
}
