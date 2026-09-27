import QtQuick
import "Colors.js" as Colors

// Společný vzhled všech vyskakovacích karet: flyouty (napájení, zvuk, síť),
// kalendář, tooltipy a menu v tray z panelu. Jedno místo pro barvu,
// rámeček, zaoblení a animaci objevení/zmizení — ať nevypadá každé jinak.
//
//     PopupCard { shown: pop.open; transformOrigin: Item.TopRight; … obsah … }
//
// `shown` řídí animaci (fade + lehké zvětšení z 96 % + sjetí o 6 px);
// okno, které kartu drží, se má skrýt až po `closeDuration`.
Rectangle {
    id: card

    property bool shown: true
    readonly property int openDuration: 160
    readonly property int closeDuration: 120

    radius: 14
    color: Qt.alpha(Colors.surfaceContainerHigh, 0.96)
    border.width: 1
    border.color: Qt.alpha(Colors.outlineVariant, 0.85)
    transformOrigin: Item.Top

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.96
    transform: Translate {
        y: card.shown ? 0 : -6
        Behavior on y { NumberAnimation { duration: card.shown ? card.openDuration : card.closeDuration; easing.type: Easing.OutCubic } }
    }
    Behavior on opacity { NumberAnimation { duration: card.shown ? card.openDuration : card.closeDuration; easing.type: Easing.OutCubic } }
    Behavior on scale {
        NumberAnimation {
            duration: card.shown ? card.openDuration : card.closeDuration
            easing.type: card.shown ? Easing.OutQuint : Easing.InQuad
        }
    }
}
