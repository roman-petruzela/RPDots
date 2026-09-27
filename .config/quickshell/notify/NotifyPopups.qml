import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win

    required property var service
    required property var niri
    property int rightInset: 0
    readonly property var cfg: service.cfg
    readonly property string pos: cfg.position || "top-right"
    readonly property bool atTop: pos.startsWith("top")

    property string outName: ""
    screen: Quickshell.screens.find(s => s.name === outName) ?? Quickshell.screens[0]
    Connections {
        target: win.service
        function onPopupsChanged() {
            if (win.service.popups.length === 0) win.outName = ""
            else if (win.outName === "") {
                const ws = win.niri.focusedWorkspace()
                win.outName = ws ? ws.output : ""
            }
        }
    }
    visible: service.popups.length > 0
    color: "transparent"
    implicitWidth: 380
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rp-notifications"
    anchors {
        top: true
        bottom: true
        left: pos.endsWith("left")
        right: pos.endsWith("right")
    }
    margins { top: 10; bottom: 10; left: 10; right: 10 + rightInset }
    mask: Region { item: stack }

    Column {
        id: stack
        width: parent.width
        spacing: 8
        y: win.atTop ? 0 : parent.height - height

        Repeater {
            model: ScriptModel { values: win.service.popups.slice(0, Math.max(1, win.cfg.max_visible || 5)) }
            NotifyCard {
                required property var modelData
                width: stack.width
                notif: modelData
                service: win.service
                popup: true
                timeoutSec: win.cfg.timeout ?? 6
                onExpired: {
                    if (modelData.transient) modelData.expire()
                    else win.service.hidePopup(modelData)
                }
                transform: Translate {
                    id: slide
                    x: win.pos.endsWith("left") ? -24 : 24
                    Component.onCompleted: x = 0
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
