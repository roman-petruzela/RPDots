import QtQuick
import "Colors.js" as Colors

// Společný vzhled vyskakovacích karet z panelu (tooltipy, kalendář, menu
// v tray) a session menu — převzatý z flyoutů (napájení, zvuk, síť), ať
// vypadá všechno jako ony: stejná barva, zaoblení, rámeček a animace
// (sjetí shora + prolnutí).
//
//     PopupCard { shown: pop.open; … obsah … }
//
// Okno, které kartu drží, se má skrýt až po `closeDuration`.
Rectangle {
    id: card

    property bool shown: true
    readonly property int openDuration: 200
    readonly property int closeDuration: 140

    radius: 16
    color: Qt.alpha(Colors.surfaceContainer, 0.94)
    border.width: 1
    border.color: Colors.outlineVariant

    opacity: shown ? 1 : 0
    transform: Translate {
        y: card.shown ? 0 : -20
        Behavior on y { NumberAnimation { duration: card.shown ? card.openDuration : card.closeDuration; easing.type: Easing.OutCubic } }
    }
    Behavior on opacity { NumberAnimation { duration: card.shown ? 160 : card.closeDuration } }
}
