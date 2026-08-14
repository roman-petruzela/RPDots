import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import "Colors.js" as Colors

// Pozn.: IPC funkce se NESMÍ jmenovat `show` — koliduje s podpříkazem
// `qs ipc show` a volání se pak jen vypíše místo provedení. Proto `trigger`.
// Zároveň `qs ipc call` v quickshellu 0.3.0 neumí předat argument, takže si
// OSD hodnotu načítá samo — hlasitost z PipeWire, jas z brightnessctl.
Item {
    id: root

    property string osdType: ""
    property real osdValue: 0.0
    property bool osdMuted: false
    property bool showing: false

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    IpcHandler {
        target: "osd-volume"
        function trigger(): void {
            if (!root.sink || !root.sink.audio) return
            root.osdType = "volume"
            root.osdMuted = root.sink.audio.muted
            root.osdValue = Math.round(root.sink.audio.volume * 100)
            root.showing = true
            hideTimer.restart()
        }
    }

    IpcHandler {
        target: "osd-brightness"
        function trigger(): void {
            brightnessProc.running = false
            brightnessProc.running = true
        }
    }

    Process {
        id: brightnessProc
        command: ["brightnessctl", "--class=backlight", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // formát: název,typ,aktuální,XX%,max
                const pct = parseFloat((text.split(",")[3] || "").replace("%", ""))
                if (isNaN(pct)) return
                root.osdType = "brightness"
                root.osdValue = pct
                root.osdMuted = false
                root.showing = true
                hideTimer.restart()
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: root.showing = false
    }

    PanelWindow {
        id: osdWindow
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        visible: root.showing

        anchors { bottom: true; right: true }
        implicitWidth: 280
        implicitHeight: 72
        margins.bottom: 48
        margins.right: 48

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 16
            color: Qt.rgba(
                Qt.color(Colors.surfaceContainer).r,
                Qt.color(Colors.surfaceContainer).g,
                Qt.color(Colors.surfaceContainer).b,
                0.92
            )
            border.color: Colors.outlineVariant
            border.width: 1

            opacity: root.showing ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Row {
                anchors {
                    fill: parent
                    leftMargin: 18; rightMargin: 18
                    topMargin: 14; bottomMargin: 14
                }
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (osdType === "brightness") return "󰃟"
                        if (osdMuted) return ""
                        if (osdValue > 66) return ""
                        if (osdValue > 33) return ""
                        return ""
                    }
                    font.pixelSize: 20
                    color: Colors.primary
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 42
                    spacing: 8

                    Text {
                        text: osdMuted ? "Ztlumeno" : Math.round(osdValue) + " %"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Colors.onSurface
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Colors.surfaceContainerHighest

                        Rectangle {
                            width: parent.width * Math.min((osdMuted ? 0 : osdValue) / 100.0, 1.0)
                            height: parent.height
                            radius: 2
                            color: osdMuted ? Colors.outline : Colors.primary

                            Behavior on width {
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
