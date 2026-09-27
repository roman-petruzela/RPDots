import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "Colors.js" as Colors

Item {
    id: root

    property var niri
    property string osdType: ""
    property real osdValue: 0
    property string osdLabel: ""
    property bool osdMuted: false
    property bool showing: false
    property string outName: ""

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    function present(type, value, muted, label) {
        const same = showing && osdType === type && osdValue === value && osdMuted === muted
        const edge = type !== "keyboard" && !muted && (value <= 0 || value >= 100)
        if (!showing) {
            const ws = niri ? niri.focusedWorkspace() : null
            outName = ws ? ws.output : ""
        }
        if (osdMuted !== muted && type === osdType) iconPop.restart()
        osdType = type
        osdValue = value
        osdMuted = muted
        osdLabel = label ?? ""
        showing = true
        hideTimer.restart()
        if (same && edge) bump.restart()
    }

    function triggerVolume() {
        if (!sink || !sink.audio) return
        present("volume", Math.round(sink.audio.volume * 100), sink.audio.muted)
    }
    function triggerBrightness() { brightnessProc.running = false; brightnessProc.running = true }
    function triggerKeyboardLayout() { keyboardLayoutProc.running = false; keyboardLayoutProc.running = true }

    IpcHandler {
        target: "osd-volume"
        function trigger(): void { root.triggerVolume() }
    }
    IpcHandler {
        target: "osd-brightness"
        function trigger(): void { root.triggerBrightness() }
    }
    IpcHandler {
        target: "osd-keyboard-layout"
        function trigger(): void { root.triggerKeyboardLayout() }
    }

    Process {
        id: brightnessProc
        command: ["brightnessctl", "--class=backlight", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseFloat((text.split(",")[3] || "").replace("%", ""))
                if (!isNaN(pct)) root.present("brightness", pct, false)
            }
        }
    }

    Process {
        id: keyboardLayoutProc
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data
                try { data = JSON.parse(text) } catch (e) { return }
                const name = data.names ? data.names[data.current_idx] : undefined
                if (name) root.present("keyboard", 0, false, name)
            }
        }
    }

    Timer { id: hideTimer; interval: 1600; onTriggered: root.showing = false }

    readonly property string icon: {
        if (osdType === "brightness") return osdValue < 34 ? "\u{f00de}" : osdValue < 67 ? "\u{f00df}" : "\u{f00e0}"
        if (osdType === "keyboard") return "\u{f030c}"
        if (osdMuted) return "\u{f075f}"
        return osdValue < 34 ? "\u{f057f}" : osdValue < 67 ? "\u{f0580}" : "\u{f057e}"
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === root.outName) ?? Quickshell.screens[0]
        visible: root.showing || pill.opacity > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        anchors.bottom: true
        margins.bottom: 56
        implicitWidth: 340
        implicitHeight: 64
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rp-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            id: pill
            readonly property real full: root.osdType === "keyboard"
                ? Math.min(win.width - 16, label.implicitWidth + height + 28) : win.width - 16
            x: Math.round((win.width - full) / 2)
            anchors.verticalCenter: parent.verticalCenter
            height: 48
            width: root.showing ? full : height
            radius: height / 2
            color: Qt.alpha(Colors.surfaceContainer, 0.94)
            border.width: 1
            border.color: Qt.alpha(Colors.outlineVariant, 0.8)
            clip: true
            opacity: root.showing ? 1 : 0

            Behavior on width {
                NumberAnimation {
                    duration: root.showing ? 300 : 200
                    easing.type: root.showing ? Easing.OutCubic : Easing.InCubic
                }
            }
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.showing ? 0 : 140 }
                    NumberAnimation { duration: root.showing ? 120 : 90 }
                }
            }

            SequentialAnimation on scale {
                id: bump
                running: false
                NumberAnimation { to: 1.04; duration: 70; easing.type: Easing.OutQuad }
                NumberAnimation { to: 1; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 3 }
            }

            Rectangle {
                id: fill
                visible: root.osdType !== "keyboard"
                height: parent.height
                radius: height / 2
                width: Math.min(pill.width, parent.height + (pill.full - parent.height) * Math.max(0, Math.min(100, root.osdMuted ? 0 : root.osdValue)) / 100)
                color: root.osdMuted ? Colors.outline : Colors.primary
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Rectangle {
                visible: root.osdType === "keyboard"
                width: parent.height; height: parent.height
                radius: height / 2
                color: Colors.primary
            }

            Text {
                id: iconText
                width: pill.height; height: pill.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.icon
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 20
                color: root.osdMuted ? Colors.surface : Colors.onPrimary
                SequentialAnimation on scale {
                    id: iconPop
                    running: false
                    NumberAnimation { to: 0.7; duration: 70; easing.type: Easing.InQuad }
                    NumberAnimation { to: 1; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                }
            }

            Text {
                id: label
                visible: root.osdType === "keyboard"
                anchors { left: parent.left; leftMargin: pill.height + 12; verticalCenter: parent.verticalCenter }
                text: root.osdLabel
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Colors.onSurface
            }

            Text {
                visible: root.osdType !== "keyboard"
                anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                opacity: pill.width > pill.full * 0.6 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                text: root.osdMuted ? "Muted" : Math.round(root.osdValue)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: fill.width > pill.width - 44 ? Colors.onPrimary : Colors.onSurface
            }
        }
    }
}
