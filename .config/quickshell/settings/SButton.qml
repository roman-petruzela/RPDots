import QtQuick
import "../Colors.js" as Colors

// Tlačítko; `danger` pro odinstalaci apod., `busy` ho ztlumí a zablokuje
Rectangle {
    id: btn
    property string text
    property string icon: ""
    property bool busy: false
    property bool danger: false
    property bool flat: false
    signal clicked()

    readonly property color accent: danger ? Colors.errorColor : Colors.primary

    width: btnRow.width + (text !== "" ? 28 : 18)
    height: 34
    radius: 10
    color: flat && !btnHover.hovered ? "transparent"
        : Qt.alpha(accent, btnHover.hovered ? 0.22 : 0.12)
    border.width: flat ? 0 : 1
    border.color: Qt.alpha(accent, 0.45)
    opacity: busy ? 0.55 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    HoverHandler { id: btnHover }

    Row {
        id: btnRow
        anchors.centerIn: parent
        height: parent.height
        spacing: 8
        Text {
            visible: btn.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: btn.accent
        }
        Text {
            visible: btn.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Colors.onSurface
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: btn.busy ? Qt.BusyCursor : Qt.PointingHandCursor
        onClicked: if (!btn.busy) btn.clicked()
    }
}
