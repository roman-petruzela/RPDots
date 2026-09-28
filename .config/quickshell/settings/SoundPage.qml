import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property var st: null
    property string blacklistText: ""

    function reload() {
        statusProc.running = false
        statusProc.running = true
    }

    function audio(args) {
        Quickshell.execDetached(["rp-audio"].concat(args))
        refresh.restart()
    }

    Component.onCompleted: reload()

    Process {
        id: statusProc
        command: ["rp-audio", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.st = JSON.parse(text)
                    page.blacklistText = page.st.blacklist.join(", ")
                } catch (e) { page.host.showError("rp-audio status failed") }
            }
        }
    }

    Process {
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser { onRead: refresh.restart() }
    }
    Timer { id: refresh; interval: 150; onTriggered: page.reload() }

    readonly property var outputs: st ? st.outputs : []
    readonly property var inputs: st ? st.inputs : []
    readonly property var defOut: outputs.find(o => o.default) ?? null
    readonly property var defIn: inputs.find(i => i.default) ?? null

    function appIcon(name) {
        return (name ? Quickshell.iconPath(name, true) : "") || Quickshell.iconPath("audio-x-generic")
    }

    function deviceIcon(desc) {
        const d = desc.toLowerCase()
        if (/hdmi|displayport|dp /.test(d)) return "󰡁"
        if (/headset|headphone|arctis|nova|hyperx cloud|buds|airpods/.test(d)) return "󰋋"
        if (/easy ?effects/.test(d)) return "󰺢"
        if (/mic|solocast|yeti/.test(d)) return "󰍬"
        return "󰓃"
    }

    component DeviceRow: Rectangle {
        id: dr
        property var dev
        property bool isInput: false
        width: parent ? parent.width : 0
        height: 48
        radius: 12
        color: dev.default ? Qt.alpha(Colors.primary, 0.14)
            : drHover.hovered ? Qt.alpha(Colors.onSurface, 0.04) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        HoverHandler { id: drHover }

        Text {
            id: drIcon
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            width: 20
            horizontalAlignment: Text.AlignHCenter
            text: page.deviceIcon(dr.dev.description)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: dr.dev.default ? Colors.primary : Colors.onSurfaceVariant
        }
        SLabel {
            anchors { left: drIcon.right; leftMargin: 12; right: drRight.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: dr.dev.description
            elide: Text.ElideRight
            font.weight: dr.dev.default ? Font.Medium : Font.Normal
        }
        Row {
            id: drRight
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 10
            Rectangle {
                visible: dr.dev.virtual
                anchors.verticalCenter: parent.verticalCenter
                width: vText.implicitWidth + 14; height: 20; radius: 10
                color: Qt.alpha(Colors.tertiary, 0.14)
                Text {
                    id: vText
                    anchors.centerIn: parent
                    text: "virtual"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: Colors.tertiary
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: dr.dev.default ? "󰄬" : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: Colors.primary
                width: 16
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!dr.dev.default)
                page.audio(dr.isInput ? ["input", dr.dev.name] : ["switch", dr.dev.name])
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

                Rectangle {
                    id: muteBtn
                    anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                    width: 48; height: 48; radius: 24
                    color: page.st?.muted ? Qt.alpha(Colors.errorColor, 0.16)
                        : muteHover.hovered ? Qt.alpha(Colors.primary, 0.22) : Qt.alpha(Colors.primary, 0.12)
                    HoverHandler { id: muteHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: page.audio(["mute", "toggle"]) }
                    Text {
                        anchors.centerIn: parent
                        text: page.st?.muted ? "󰝟" : (page.st?.volume ?? 0) > 50 ? "󰕾" : "󰖀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: page.st?.muted ? Colors.errorColor : Colors.primary
                    }
                }
                Column {
                    anchors { left: muteBtn.right; leftMargin: 18; right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    SLabel {
                        width: parent.width
                        elide: Text.ElideRight
                        text: page.defOut ? page.defOut.description : "No output"
                        font.weight: Font.Medium
                    }
                    SSlider {
                        width: parent.width
                        from: 0; to: 100; step: 1
                        value: page.st?.volume ?? 0
                        suffix: "%"
                        onMoved: v => page.audio(["volume", "set", String(Math.round(v))])
                    }
                }
            }

            SHint {
                width: parent.width
                leftPadding: 14; rightPadding: 14; topPadding: 8
                text: "Volume is the same on every output, so switching never jumps. Apps below can be set on their own."
            }

            SHeading { text: "OUTPUT" }
            Repeater {
                model: page.outputs
                DeviceRow { required property var modelData; dev: modelData }
            }
            SRow {
                visible: (page.defOut?.ports.length ?? 0) > 1
                label: "Output port"
                hint: "Which connector of " + (page.defOut?.description ?? "") + " to use."
                SDropdown {
                    options: page.defOut ? page.defOut.ports.map(p => p.name) : []
                    labels: page.defOut ? page.defOut.ports.map(p => p.description + (p.available ? "" : " (unplugged)")) : []
                    current: page.defOut?.port ?? ""
                    onPicked: v => page.audio(["port", page.defOut.name, v])
                }
            }

            SHeading { text: "INPUT" }
            Repeater {
                model: page.inputs
                DeviceRow { required property var modelData; dev: modelData; isInput: true }
            }
            SRow {
                visible: page.defIn !== null
                label: "Input volume"
                hint: page.defIn?.description ?? ""
                Row {
                    spacing: 10
                    SSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 150; step: 1
                        value: page.defIn?.volume ?? 0
                        suffix: "%"
                        onMoved: v => page.audio(["source-volume", page.defIn.name, String(Math.round(v))])
                    }
                    SButton {
                        anchors.verticalCenter: parent.verticalCenter
                        danger: page.defIn?.muted ?? false
                        icon: page.defIn?.muted ? "󰍭" : "󰍬"
                        text: ""
                        onClicked: page.audio(["source-mute", page.defIn.name, "toggle"])
                    }
                }
            }

            SHeading { text: "APPLICATIONS" }
            SHint {
                visible: (page.st?.streams.length ?? 0) === 0
                leftPadding: 14; bottomPadding: 6
                text: "Nothing is playing."
            }
            Repeater {
                model: page.st?.streams ?? []
                Item {
                    id: sr
                    required property var modelData
                    width: col.width
                    height: 60

                    IconImage {
                        id: appIconImg
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        implicitSize: 28
                        source: page.appIcon(sr.modelData.icon)
                    }
                    Column {
                        anchors { left: appIconImg.right; leftMargin: 12; right: srControls.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        SLabel { width: parent.width; elide: Text.ElideRight; text: sr.modelData.app }
                        SHint {
                            width: parent.width
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            text: sr.modelData.media + (sr.modelData.corked ? " · paused" : "")
                        }
                    }
                    Row {
                        id: srControls
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        SSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 220
                            from: 0; to: 150; step: 1
                            value: sr.modelData.volume
                            suffix: "%"
                            onMoved: v => page.audio(["stream-volume", String(sr.modelData.id), String(Math.round(v))])
                        }
                        SButton {
                            anchors.verticalCenter: parent.verticalCenter
                            danger: sr.modelData.muted
                            icon: sr.modelData.muted ? "󰝟" : "󰕾"
                            text: ""
                            onClicked: page.audio(["stream-mute", String(sr.modelData.id), "toggle"])
                        }
                        SDropdown {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 170
                            options: page.outputs.map(o => String(o.id))
                            labels: page.outputs.map(o => o.description)
                            current: String(sr.modelData.sink)
                            onPicked: v => page.audio(["stream-move", String(sr.modelData.id), v])
                        }
                    }
                }
            }

            SHeading {
                visible: (page.st?.recording.length ?? 0) > 0
                text: "USING THE MICROPHONE"
            }
            Repeater {
                model: page.st?.recording ?? []
                SRow {
                    required property var modelData
                    label: modelData.app
                    hint: modelData.media
                    SDropdown {
                        width: 220
                        options: page.inputs.map(i => String(i.id))
                        labels: page.inputs.map(i => i.description)
                        current: String(modelData.source)
                        onPicked: v => page.audio(["rec-move", String(modelData.id), v])
                    }
                }
            }

            SHeading { text: "DEVICES" }
            SHint {
                width: parent.width
                leftPadding: 14; rightPadding: 14; bottomPadding: 6
                text: "The profile decides what a device offers — e.g. a headset with or without its microphone. Off hides it."
            }
            Repeater {
                model: page.st?.cards ?? []
                SRow {
                    required property var modelData
                    label: modelData.description
                    SDropdown {
                        width: 300
                        options: modelData.profiles.map(p => p.name)
                        labels: modelData.profiles.map(p => p.description)
                        current: modelData.profile
                        onPicked: v => page.audio(["profile", modelData.name, v])
                    }
                }
            }

            SHeading { text: "ADVANCED" }
            SRow {
                label: "Apps that keep their own output"
                hint: "They don't follow when you switch outputs (OBS, Easy Effects…). Comma-separated."
                STextBox {
                    width: 260
                    value: page.blacklistText
                    onCommitted: v => page.audio(["blacklist", v])
                }
            }
            SRow {
                label: "More audio tools"
                hint: "pavucontrol for everything else, Easy Effects for EQ and filters."
                Row {
                    spacing: 8
                    SButton { icon: "󰕾"; text: "pavucontrol"; onClicked: Quickshell.execDetached(["pavucontrol"]) }
                    SButton { icon: "󰺢"; text: "Easy Effects"; onClicked: Quickshell.execDetached(["easyeffects"]) }
                }
            }
        }
    }
}
