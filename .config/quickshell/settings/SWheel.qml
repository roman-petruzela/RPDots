import QtQuick

Item {
    id: w
    required property Flickable flick
    property real notch: 120
    parent: flick
    anchors.fill: parent
    z: 1000

    readonly property real minY: flick.originY
    readonly property real maxY: flick.originY + Math.max(0, flick.contentHeight - flick.height)

    function clamp(y) { return Math.max(minY, Math.min(maxY, y)) }

    NumberAnimation {
        id: anim
        target: w.flick
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.pixelDelta.y !== 0) {
                anim.stop()
                w.flick.contentY = w.clamp(w.flick.contentY - event.pixelDelta.y)
            } else {
                const base = anim.running ? anim.to : w.flick.contentY
                anim.stop()
                anim.to = w.clamp(base - event.angleDelta.y / 120 * w.notch)
                anim.start()
            }
            event.accepted = true
        }
    }
}
