import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "dash"
import "Colors.js" as Colors

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    anchors { left: true; right: true; top: true; bottom: true }

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region { item: panel }

    property int barHeight: 36
    property var barData
    property var caffeine
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    property var volPending: null
    property var blPending: null
    Process {
        id: volProc
        environment: ({ RP_AUDIO_NO_OSD: "1" })
        onExited: if (root.volPending !== null) root.setVolume(root.volPending)
    }
    Process {
        id: blSet
        onExited: {
            if (root.blPending !== null) root.setBrightness(root.blPending)
            else if (root.barData) root.barData.refreshBrightness()
        }
    }
    function setVolume(v) {
        if (volProc.running) { root.volPending = v; return }
        root.volPending = null
        volProc.command = [root.bin + "rp-audio", "volume", "set", String(v)]
        volProc.running = true
    }
    function setBrightness(v) {
        if (blSet.running) { root.blPending = v; return }
        root.blPending = null
        blSet.command = ["brightnessctl", "--class=backlight", "-q", "set", Math.max(1, v) + "%"]
        blSet.running = true
    }
    property real slideX: 380

    Behavior on slideX {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    onVisibleChanged: {
        if (visible) {
            slideX = 0
        } else {
            slideX = 380
            scroll.contentY = 0
        }
    }

    FocusedOutput { id: opener; window: root }

    function open()   { opener.show() }
    function toggle() { if (root.visible) root.visible = false; else root.open() }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.visible = false
    }

    Rectangle {
        id: panel
        x: parent.width - width + slideX
        y: root.barHeight
        width: 380
        height: parent.height - root.barHeight

        color: Qt.rgba(Qt.color(Colors.surfaceContainer).r,
                       Qt.color(Colors.surfaceContainer).g,
                       Qt.color(Colors.surfaceContainer).b, 0.90)

        Rectangle {
            x: 0; y: 0; width: 1; height: parent.height
            color: Colors.outlineVariant
            opacity: 0.5
        }

        MouseArea { anchors.fill: parent }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 1
            opacity: 1.0 - (slideX / 380) * 0.4
            clip: true

            DashHeader {
                id: header
                anchors { left: parent.left; right: parent.right; top: parent.top }
            }

            Flickable {
                id: scroll
                anchors {
                    left: parent.left; right: parent.right
                    top: header.bottom; bottom: quickActions.top
                    topMargin: 6; bottomMargin: 12
                    leftMargin: 20; rightMargin: 20
                }
                contentHeight: col.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: col
                    width: parent.width
                    spacing: 16

                    DashToggles {
                        width: parent.width
                        caffeine: root.caffeine
                        polling: root.visible
                        onRequestClose: root.visible = false
                    }

                    Column {
                        width: parent.width
                        spacing: 8

                        DashSlider {
                            width: parent.width
                            visible: !!root.barData
                            icon: !root.barData ? "" : root.barData.muted ? "\u{f075f}"
                                : root.barData.volume < 34 ? "\u{f057f}" : root.barData.volume < 67 ? "\u{f0580}" : "\u{f057e}"
                            value: root.barData ? root.barData.volume : 0
                            dimmed: root.barData ? root.barData.muted : false
                            onMoved: v => root.setVolume(v)
                            onReleased: v => root.setVolume(v)
                            onIconClicked: Quickshell.execDetached([root.bin + "rp-audio", "mute", "toggle"])
                        }
                        DashSlider {
                            width: parent.width
                            visible: !!root.barData && root.barData.hasBacklight
                            icon: value < 34 ? "\u{f00de}" : value < 67 ? "\u{f00df}" : "\u{f00e0}"
                            value: root.barData ? root.barData.brightness : 0
                            onMoved: v => root.setBrightness(v)
                            onReleased: v => root.setBrightness(v)
                        }
                    }

                    MediaWidget { id: mediaWidget; width: parent.width }

                    SystemWidget { width: parent.width; active: root.visible }
                }
            }

            QuickActionsWidget {
                id: quickActions
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                          leftMargin: 20; rightMargin: 20; bottomMargin: 16 }
            }
        }
    }
}
