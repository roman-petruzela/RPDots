import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property bool active: false
    property url source: ""

    property bool shown: false
    visible: shown
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "rp-wallpaper-preview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    property bool frontIsA: true

    onSourceChanged: if (active) load()

    function load() {
        const front = frontIsA ? imgA : imgB
        const back = frontIsA ? imgB : imgA
        if (front.source.toString() === source.toString()) return
        if (back.source.toString() === source.toString() && back.status === Image.Ready) frontIsA = !frontIsA
        else back.source = source
    }

    onActiveChanged: {
        if (active) {
            fadeOut.stop()
            content.opacity = 1
            shown = true
            load()
        } else if (shown) {
            fadeOut.start()
        }
    }

    Item {
        id: content
        anchors.fill: parent

        NumberAnimation on opacity {
            id: fadeOut
            running: false
            to: 0
            duration: 160
            onFinished: {
                root.shown = false
                imgA.source = ""
                imgB.source = ""
            }
        }

        Image {
            id: imgA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(root.width, root.height)
            opacity: root.frontIsA ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready && !root.frontIsA && source.toString() === root.source.toString()) root.frontIsA = true
        }

        Image {
            id: imgB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(root.width, root.height)
            opacity: root.frontIsA ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready && root.frontIsA && source.toString() === root.source.toString()) root.frontIsA = false
        }
    }
}
