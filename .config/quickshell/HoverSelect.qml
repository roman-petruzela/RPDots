import QtQuick

// MouseArea pro seznamy ovládané klávesnicí: `moved()` hlásí jen skutečný
// pohyb kurzoru. Obyčejné onEntered/onPositionChanged chodí i tehdy, když se
// pod stojícím kurzorem posune obsah (rychlé listování šipkami) nebo když se
// okno otevře pod ním — výběr pak skákal na položku pod myší.
//
// Porovnává se poloha ve scéně: posun obsahu ji nemění, pohyb myši ano. První
// událost po najetí se jen zapamatuje, takže se nic nevybere samo od sebe.
MouseArea {
    id: area

    signal moved()

    property point last: Qt.point(-1, -1)

    hoverEnabled: true

    onExited: last = Qt.point(-1, -1)
    onPositionChanged: mouse => {
        const p = area.mapToItem(null, mouse.x, mouse.y)
        const first = last.x < 0
        const same = p.x === last.x && p.y === last.y
        last = p
        if (!first && !same) area.moved()
    }
}
