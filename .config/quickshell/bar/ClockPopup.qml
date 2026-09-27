import QtQuick
import ".."
import "../Colors.js" as Colors

BarPopup {
    id: pop
    property bool targetHovered: false
    readonly property bool anyHovered: targetHovered || hovered
    padding: 12
    grabFocus: true

    function toggle() {
        if (open) { dismiss(); return }
        cal.reset()
        show()
        if (!anyHovered) closeDelay.restart()
    }

    Timer { id: closeDelay; interval: 1200; onTriggered: if (!pop.anyHovered) pop.dismiss() }
    onAnyHoveredChanged: if (anyHovered) closeDelay.stop(); else if (open) closeDelay.restart()

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
            function reset() {
                const d = new Date()
                viewYear = d.getFullYear()
                viewMonth = d.getMonth()
                build()
            }
        }
    }
}
