import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Řádek nastavení: popis vlevo, ovládací prvek vpravo, obojí svisle na středu.
// Tečka za popisem = hodnota se liší od výchozí; kliknutí ji vrátí.
Item {
    id: row
    property string label
    property string hint
    property string icon: ""
    property bool changed: false
    signal resetRequested()
    default property alias control: slot.data

    width: parent ? parent.width : 0
    height: Math.max(52, texts.implicitHeight + 22)

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: hover.hovered ? Qt.alpha(Colors.onSurface, 0.04) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    HoverHandler { id: hover }

    Text {
        id: iconText
        visible: row.icon !== ""
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        width: 20
        horizontalAlignment: Text.AlignHCenter
        text: row.icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        color: Colors.onSurfaceVariant
    }

    Column {
        id: texts
        anchors {
            left: row.icon !== "" ? iconText.right : parent.left
            leftMargin: row.icon !== "" ? 12 : 14
            right: slot.left; rightMargin: 20
            verticalCenter: parent.verticalCenter
        }
        spacing: 3
        Item {
            width: parent.width
            height: labelText.implicitHeight
            SLabel { id: labelText; text: row.label; width: Math.min(implicitWidth, parent.width - 22); elide: Text.ElideRight }
            Rectangle {
                visible: row.changed
                anchors { left: labelText.right; leftMargin: 4; verticalCenter: labelText.verticalCenter }
                width: 14; height: 14; radius: 7
                color: dotHover.hovered ? Qt.alpha(Colors.tertiary, 0.2) : "transparent"
                Rectangle {
                    anchors.centerIn: parent
                    width: 6; height: 6; radius: 3
                    color: Colors.tertiary
                }
                HoverHandler { id: dotHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: row.resetRequested() }
                ToolTip.visible: dotHover.hovered
                ToolTip.text: "Changed — click to reset"
                ToolTip.delay: 400
            }
        }
        SHint { visible: row.hint !== ""; text: row.hint; width: parent.width }
    }

    Item {
        id: slot
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: childrenRect.height
    }
}
