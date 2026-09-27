import QtQuick
import ".."
import "../Colors.js" as Colors

// Kalendář pod hodinami v panelu (BarPopup — stejné okno a karta jako
// tooltipy a menu). Ukáže se po najetí na hodiny a zůstane, dokud je myš
// na hodinách nebo na něm (šipkami jde listovat měsíce).
BarPopup {
    id: pop
    property bool targetHovered: false
    readonly property bool anyHovered: targetHovered || hovered
    padding: 12

    // Otevřít po krátké prodlevě, zavřít až chvíli po odjetí myši (přejezd
    // z hodin do kalendáře ho nesmí zavřít)
    Timer { id: openDelay; interval: 300; onTriggered: if (pop.anyHovered) { cal.reset(); pop.show() } }
    Timer { id: closeDelay; interval: 350; onTriggered: if (!pop.anyHovered) pop.dismiss() }
    onAnyHoveredChanged: {
        if (anyHovered) { closeDelay.stop(); if (!open) openDelay.restart() }
        else { openDelay.stop(); closeDelay.restart() }
    }

    property var now: new Date()
    Timer { interval: 1000; running: pop.visible; repeat: true; triggeredOnStart: true; onTriggered: pop.now = new Date() }

    Column {
        width: 226
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
