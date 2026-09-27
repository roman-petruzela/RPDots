import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

// Společný základ vyskakovacích oken pod barem (přepínač zvuku, power režimy).
// Obsah se vkládá jako běžné děti — skládají se do sloupce uvnitř karty:
//
//     Flyout { title: "Audio output"; Text { ... } }
//
// Zavírá se kliknutím mimo kartu nebo Escapem; kliknutí uvnitř ji nechává
// otevřenou, aby šlo přepínat víckrát za sebou.
PanelWindow {
    id: root

    default property alias content: col.data

    property string heading: ""
    property int cardWidth: 380
    property int barHeight: 36     // výška waybaru

    // Zavolá se při každém otevření — na dotažení čerstvých dat.
    signal opened()

    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) root.opened()

    // Rozmazané pozadí pod kartou (jako kalendář, tooltipy a menu z panelu)
    BackgroundEffect.blurRegion: Region { item: card; radius: card.radius }

    // U více monitorů má okno vyjet na tom, na kterém zrovna pracuješ.
    FocusedOutput { id: opener; window: root }

    function open() { opener.show() }

    function toggle() {
        if (root.visible) root.visible = false
        else root.open()
    }

    // Zavření kliknutím mimo kartu
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.visible = false
    }

    // Vzhled a animace společné se všemi vyskakovacími kartami (PopupCard)
    PopupCard {
        id: card

        anchors.right: parent.right
        anchors.rightMargin: 8
        y: root.barHeight + 8

        width: root.cardWidth
        height: col.implicitHeight + 28
        shown: root.visible
        transformOrigin: Item.TopRight

        // Kliknutí na kartu nesmí propadnout na zavírací vrstvu pod ní
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors {
                fill: parent
                topMargin: 14; bottomMargin: 14
                leftMargin: 16; rightMargin: 16
            }
            spacing: 4

            Text {
                text: root.heading
                visible: text !== ""
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.onSurfaceVariant
                bottomPadding: 6
            }
        }
    }
}
