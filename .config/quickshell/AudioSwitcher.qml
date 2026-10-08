import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "Colors.js" as Colors

Flyout {
    id: root

    heading: "Audio output"

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)

    PwObjectTracker { objects: root.sinks }

    readonly property PwNode active: Pipewire.defaultAudioSink
    readonly property real volume: active && active.audio ? active.audio.volume : 0
    readonly property bool muted: active && active.audio ? active.audio.muted : false

    Process { id: mixerProc; command: ["bash", "-c", "$HOME/.local/bin/rp-shell settings sound"] }
    Process { id: unpinProc; command: ["bash", "-c", "rp-audio unpin"] }

    function selectSink(node) {
        Pipewire.preferredDefaultAudioSink = node
        unpinProc.running = false
        unpinProc.running = true
    }

    function selectNext() {
        if (root.sinks.length < 2) return
        const cur = root.active
            ? root.sinks.findIndex(s => s.id === root.active.id)
            : -1
        root.selectSink(root.sinks[(cur + 1) % root.sinks.length])
    }

    Timer {
        id: volumeBeep
        interval: 200
        onTriggered: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rp-sound", "volume"])
    }

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

    Repeater {
        model: root.sinks

        Rectangle {
            required property var modelData

            width: root.cardWidth - 32
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
                onClicked: root.selectSink(modelData)
            }
        }
    }

    Item { width: 1; height: 8 }
    Divider { width: root.cardWidth - 32 }
    Item { width: 1; height: 10 }

    Row {
        width: root.cardWidth - 32
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
                onReleased: volumeBeep.restart()
                onWheel: e => {
                    root.setVolumeAll(root.volume + (e.angleDelta.y > 0 ? 0.02 : -0.02))
                    volumeBeep.restart()
                }
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

    Item { width: 1; height: 12 }

    Row {
        width: root.cardWidth - 32
        spacing: 8

        Repeater {
            model: [
                { icon: "󰑐", label: "Reset apps",     action: "unpin" },
                { icon: "󰒓", label: "Sound settings", action: "mixer" },
            ]

            Rectangle {
                required property var modelData

                width: (root.cardWidth - 32 - 8) / 2
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
                            root.hide()
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
