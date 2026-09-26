import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."
import "../Colors.js" as Colors

// Kalendář pod hodinami v panelu: ukáže se po najetí na hodiny a zůstane,
// dokud je myš na hodinách nebo na něm (šipkami jde listovat měsíce).
// Karta jako v Settings — podklad, rámeček, rozmazané pozadí.
PopupWindow {
    id: pop
    required property Item target
    property bool targetHovered: false
    readonly property bool hovered: targetHovered || cardHover.hovered

    anchor.item: target
    anchor.rect.x: target.width / 2 - implicitWidth / 2
    anchor.rect.y: target.height + 10
    implicitWidth: 250
    implicitHeight: col.implicitHeight + 24
    color: "transparent"
    visible: false

    BackgroundEffect.blurRegion: Region { item: card; radius: 14 }

    // Otevřít po krátké prodlevě, zavřít až chvíli po odjetí myši (přejezd
    // z hodin do kalendáře ho nesmí zavřít)
    Timer { id: openDelay; interval: 300; onTriggered: if (pop.hovered) { cal.reset(); pop.visible = true } }
    Timer { id: closeDelay; interval: 350; onTriggered: if (!pop.hovered) pop.visible = false }
    onHoveredChanged: {
        if (hovered) { closeDelay.stop(); if (!visible) openDelay.restart() }
        else { openDelay.stop(); closeDelay.restart() }
    }

    property var now: new Date()
    Timer { interval: 1000; running: pop.visible; repeat: true; triggeredOnStart: true; onTriggered: pop.now = new Date() }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 14
        color: Qt.alpha(Colors.surface, 0.9)
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.8)
        HoverHandler { id: cardHover }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            Column {
                spacing: 2
                Text {
                    text: Qt.formatTime(pop.now, "HH:mm:ss")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: Colors.onSurface
                }
                Text {
                    text: Qt.formatDate(pop.now, "dddd d. MMMM yyyy")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: Colors.primary
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.alpha(Colors.outlineVariant, 0.7) }

            CalendarWidget {
                id: cal
                width: parent.width
                cell: 22
                // Při každém otevření zpátky na aktuální měsíc
                function reset() {
                    const d = new Date()
                    viewYear = d.getFullYear()
                    viewMonth = d.getMonth()
                    build()     // CalendarWidget se sám přepočítá jen po šipkách
                }
            }
        }
    }
}
