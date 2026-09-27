import Quickshell
import QtQuick

Item {
    id: root

    required property var window
    required property Item target

    property real fromScale: 0.94
    property real toScaleOnClose: 0.97
    property int openDuration: 220
    property int closeDuration: 140

    property real t: 0
    property bool closing: false
    readonly property bool shown: window.visible && !closing

    readonly property real s: target.scale
    readonly property bool blurOn: t > 0.3
    readonly property int blurX: blurOn ? Math.round(target.x + target.width * (1 - s) / 2) : 0
    readonly property int blurY: blurOn ? Math.round(target.y + target.height * (1 - s) / 2) : 0
    readonly property int blurW: blurOn ? Math.round(target.width * s) : 0
    readonly property int blurH: blurOn ? Math.round(target.height * s) : 0
    readonly property int blurRadius: Math.round((target.radius ?? 0) * s)

    visible: false

    Binding {
        target: root.target
        property: "opacity"
        value: Math.min(1, root.t)
    }
    Binding {
        target: root.target
        property: "scale"
        value: root.closing
            ? root.toScaleOnClose + (1 - root.toScaleOnClose) * root.t
            : root.fromScale + (1 - root.fromScale) * root.t
    }

    NumberAnimation {
        id: anim
        target: root
        property: "t"
        onFinished: {
            if (root.closing) {
                root.closing = false
                root.window.visible = false
            }
        }
    }

    function animateTo(v) {
        anim.stop()
        anim.to = v
        anim.duration = v > 0 ? openDuration : closeDuration
        anim.easing.type = v > 0 ? Easing.OutQuint : Easing.InQuad
        anim.start()
    }

    function dismiss() {
        if (!window.visible || closing) return
        closing = true
        animateTo(0)
    }

    function cancelClose() {
        if (!closing) return false
        closing = false
        animateTo(1)
        return true
    }

    Connections {
        target: root.window
        function onVisibleChanged() {
            anim.stop()
            root.closing = false
            root.t = 0
            if (root.window.visible) root.animateTo(1)
        }
    }
}
