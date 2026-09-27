import QtQuick

MouseArea {
    id: area

    signal moved()

    property point last: Qt.point(-1, -1)

    hoverEnabled: true

    onExited: last = Qt.point(-1, -1)
    onPositionChanged: mouse => {
        const m = area.mapToItem(null, mouse.x, mouse.y)
        const p = Qt.point(Math.round(m.x), Math.round(m.y))
        const first = last.x < 0
        const same = p.x === last.x && p.y === last.y
        last = p
        if (!first && !same) area.moved()
    }
}
