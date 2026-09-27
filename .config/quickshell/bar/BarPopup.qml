import Quickshell
import QtQuick
import ".."

PopupWindow {
    id: pop

    default property alias content: inner.data
    required property Item target
    property int padding: 12
    property bool alignRight: false
    property bool open: false
    readonly property bool hovered: cardHover.hovered
    readonly property alias card: card

    function show() { hideTimer.stop(); visible = true; open = true }
    function dismiss() { if (!visible) return; open = false; hideTimer.restart() }
    Timer { id: hideTimer; interval: card.closeDuration + 20; onTriggered: if (!pop.open) pop.visible = false }

    anchor.item: target
    anchor.rect.x: alignRight ? target.width - implicitWidth : target.width / 2 - implicitWidth / 2
    anchor.rect.y: target.height + 10
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY
    implicitWidth: inner.childrenRect.width + 2 * padding
    implicitHeight: inner.childrenRect.height + 2 * padding
    color: "transparent"
    visible: false

    PopupCard {
        id: card
        anchors.fill: parent
        shown: pop.open
        focus: true
        Keys.onEscapePressed: pop.dismiss()
        HoverHandler { id: cardHover }

        Item {
            id: inner
            x: pop.padding
            y: pop.padding
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
