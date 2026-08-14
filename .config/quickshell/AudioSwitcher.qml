import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "Colors.js" as Colors

// Přepínač zvukového výstupu ve stylu Windows — vyjede pod waybarem vpravo.
// Hlasitost se vždy nastavuje na všechna zařízení naráz, aby přepnutí mezi
// nimi nebylo slyšet jako skok.
PanelWindow {
    id: root

    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    readonly property int cardWidth: 380
    readonly property int barHeight: 36     // výška waybaru

    // Všechny reálné výstupy (ne streamy aplikací)
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    // Bez trackeru nejsou props (hlasitost, mute) živé
    PwObjectTracker { objects: root.sinks }

    readonly property PwNode active: Pipewire.defaultAudioSink
    readonly property real volume: active && active.audio ? active.audio.volume : 0
    readonly property bool muted: active && active.audio ? active.audio.muted : false

    property real slideY: -20

    Behavior on slideY {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    onVisibleChanged: slideY = visible ? 0 : -20

    Process { id: mixerProc; command: ["pavucontrol"] }
    Process { id: unpinProc; command: ["bash", "-c", "$HOME/.local/bin/rp-audio unpin"] }

    // U více monitorů má okno vyjet na tom, na kterém zrovna pracuješ.
    // Obrazovka se nastaví ještě před zobrazením, aby okno neposkočilo.
    Process {
        id: outputProc
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const name = JSON.parse(text).name
                    const match = Quickshell.screens.find(s => s.name === name)
                    if (match) root.screen = match
                } catch (e) {
                    // niri neodpovědělo — zůstaneme na výchozí obrazovce
                }
                root.visible = true
            }
        }
    }

    function toggle() {
        if (root.visible) root.visible = false
        else openSwitcher()
    }

    // Přepnutí na další výstup bez otevírání okna (pro klávesovou zkratku)
    function selectNext() {
        if (root.sinks.length < 2) return
        const cur = root.active
            ? root.sinks.findIndex(s => s.id === root.active.id)
            : -1
        root.selectSink(root.sinks[(cur + 1) % root.sinks.length])
    }

    function openSwitcher() {
        outputProc.running = false
        outputProc.running = true
    }

    function selectSink(node) {
        Pipewire.preferredDefaultAudioSink = node
        // Uvolní streamy, které se předtím přilepily na konkrétní zařízení
        unpinProc.running = false
        unpinProc.running = true
    }

    // Hlasitost jde na všechna zařízení, ne jen na to výchozí
    function setVolumeAll(v) {
        const clamped = Math.max(0, Math.min(1, v))
        for (const s of root.sinks)
            if (s.audio) s.audio.volume = clamped
    }

    function setMutedAll(m) {
        for (const s of root.sinks)
            if (s.audio) s.audio.muted = m
    }

    function iconFor(node) {
        const tag = ((node.name || "") + " " + (node.description || "")).toLowerCase()
        if (tag.includes("bluez") || tag.includes("bluetooth")) return "󰂯"
        if (tag.includes("hdmi") || tag.includes("displayport")) return "󰍹"
        if (tag.includes("headphone") || tag.includes("headset") || tag.includes("usb")) return "󰋋"
        return "󰓃"
    }

    function volumeIcon() {
        if (root.muted) return "󰝟"
        if (root.volume >= 0.6) return "󰕾"
        if (root.volume >= 0.2) return "󰖀"
        return "󰕿"
    }

    // Zavření kliknutím mimo kartu
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // Esc zavírá
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.visible = false
    }

    Rectangle {
        id: card

        anchors.right: parent.right
        anchors.rightMargin: 8
        y: root.barHeight + 8 + root.slideY

        width: root.cardWidth
        height: content.implicitHeight + 28
        radius: 16

        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        color: Qt.rgba(Qt.color(Colors.surfaceContainer).r,
                       Qt.color(Colors.surfaceContainer).g,
                       Qt.color(Colors.surfaceContainer).b, 0.94)
        border.color: Colors.outlineVariant
        border.width: 1

        // Kliknutí na kartu nesmí propadnout na zavírací vrstvu
        MouseArea {
            anchors.fill: parent
            onWheel: e => root.setVolumeAll(root.volume + (e.angleDelta.y > 0 ? 0.02 : -0.02))
        }

        Column {
            id: content
            anchors {
                fill: parent
                topMargin: 14; bottomMargin: 14
                leftMargin: 16; rightMargin: 16
            }
            spacing: 4

            Text {
                text: "Výstup zvuku"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.onSurfaceVariant
                bottomPadding: 6
            }

            // ── Seznam výstupů ─────────────────────────────────────────
            Repeater {
                model: root.sinks

                Rectangle {
                    required property var modelData

                    width: content.width
                    height: 54
                    radius: 12

                    readonly property bool isActive:
                        root.active && modelData.id === root.active.id

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
                            text: root.iconFor(modelData)
                            font.pixelSize: 18
                            font.family: "JetBrainsMono Nerd Font"
                            color: isActive ? Colors.primary : Colors.onSurfaceVariant
                        }

                        // Krátký název nahoře, plný popis pod ním — jako ve Windows
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 62
                            spacing: 2

                            Text {
                                width: parent.width
                                text: modelData.nickname || modelData.description || modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"
                                font.weight: isActive ? Font.Medium : Font.Normal
                                color: isActive ? Colors.onSurface : Colors.onSurfaceVariant
                            }
                            Text {
                                width: parent.width
                                text: modelData.description || ""
                                visible: text !== "" && text !== (modelData.nickname || "")
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
                        onClicked: {
                            root.selectSink(modelData)
                            root.visible = false
                        }
                    }
                }
            }

            Item { width: parent.width; height: 8 }
            Divider { width: parent.width }
            Item { width: parent.width; height: 10 }

            // ── Hlasitost (společná pro všechna zařízení) ──────────────
            Row {
                width: parent.width
                height: 28
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.volumeIcon()
                    font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                    color: root.muted ? Colors.outline : Colors.primary

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setMutedAll(!root.muted)
                    }
                }

                // Vlastní slider — táhne se i kliknutím kamkoli do dráhy
                Item {
                    id: slider
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30 - 46
                    height: 24

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 5
                        radius: 3
                        color: Colors.surfaceContainerHighest

                        Rectangle {
                            width: parent.width * (root.muted ? 0 : root.volume)
                            height: parent.height
                            radius: 3
                            color: root.muted ? Colors.outline : Colors.primary
                        }
                    }

                    Rectangle {
                        width: 13; height: 13; radius: 7
                        x: (slider.width - width) * (root.muted ? 0 : root.volume)
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.muted ? Colors.outline : Colors.primary
                        border.color: Colors.surfaceContainer
                        border.width: 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: e => root.setVolumeAll(e.x / slider.width)
                        onPositionChanged: e => {
                            if (pressed) root.setVolumeAll(e.x / slider.width)
                        }
                        onWheel: e => root.setVolumeAll(
                            root.volume + (e.angleDelta.y > 0 ? 0.02 : -0.02))
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(root.volume * 100) + " %"
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.onSurfaceVariant
                }
            }

            Item { width: parent.width; height: 12 }

            // ── Akce ───────────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: [
                        { icon: "󰑐", label: "Srovnat aplikace", action: "unpin" },
                        { icon: "󰒓", label: "Nastavení zvuku",  action: "mixer" },
                    ]

                    Rectangle {
                        required property var modelData

                        width: (content.width - 8) / 2
                        height: 34
                        radius: 10
                        color: btnHover.containsMouse
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
                                font.pixelSize: 13
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
                            id: btnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.action === "mixer") {
                                    mixerProc.running = true
                                    root.visible = false
                                } else {
                                    unpinProc.running = false
                                    unpinProc.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
