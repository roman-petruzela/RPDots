import Quickshell
import QtQuick
import "../Colors.js" as Colors

// Hlavička dashboardu: výřez aktuální tapety (tatáž zmenšenina, kterou
// apply-wallpaper-theme.sh dělá pro matugen) a přes něj velké hodiny.
// Jediný výrazný prvek dashboardu — ukazuje, z čeho se celý rice barví.
Item {
    id: head

    property string subtitle: ""           // síť apod., pod datem
    property var now: new Date()
    implicitHeight: 176

    Timer { interval: 1000; running: head.visible; repeat: true; triggeredOnStart: true; onTriggered: head.now = new Date() }

    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.cache/niri-rice/wal-matugen.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: 760
    }

    // Tapeta přechází do barvy panelu, ať text dole čte na jakékoli tapetě
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Colors.surfaceContainer, 0.15) }
            GradientStop { position: 0.55; color: Qt.alpha(Colors.surfaceContainer, 0.55) }
            GradientStop { position: 1.0; color: Qt.alpha(Colors.surfaceContainer, 0.98) }
        }
    }

    Column {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 22; rightMargin: 22; bottomMargin: 14 }
        spacing: 2

        Row {
            spacing: 6
            Text {
                id: hm
                text: Qt.formatTime(head.now, "HH:mm")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 56
                font.weight: Font.Light
                color: Colors.onSurface
            }
            Text {
                anchors.baseline: hm.baseline
                text: Qt.formatTime(head.now, "ss")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: Colors.primary
            }
        }
        Text {
            text: Qt.formatDate(head.now, "dddd d. MMMM")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: Colors.onSurface
        }
        Text {
            visible: head.subtitle !== ""
            text: head.subtitle
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: Colors.onSurfaceVariant
        }
    }
}
