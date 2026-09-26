import QtQuick
import "../Colors.js" as Colors

// Textové pole. `committed` po Enteru nebo opuštění pole (nastavení),
// `edited` při každé změně (hledání). `icon` = ikona vlevo.
Rectangle {
    id: tb
    property string value
    property string placeholder: ""
    property string icon: ""
    // false: jen Enter (pole, kde by odchod kliknutím nechtěně spustil akci)
    property bool commitOnBlur: true
    property alias text: input.text
    property alias inputItem: input
    signal committed(string value)
    signal edited(string value)

    width: 240
    height: 34
    radius: 10
    color: Colors.surfaceContainerHighest
    border.width: 1
    border.color: input.activeFocus ? Colors.primary : Colors.outlineVariant
    onValueChanged: if (!input.activeFocus) input.text = value

    Text {
        id: iconText
        visible: tb.icon !== ""
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        text: tb.icon
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: Colors.onSurfaceVariant
    }

    TextInput {
        id: input
        anchors {
            left: tb.icon !== "" ? iconText.right : parent.left; leftMargin: tb.icon !== "" ? 8 : 12
            right: parent.right; rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        text: tb.value
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: Colors.onSurface
        selectionColor: Qt.alpha(Colors.primary, 0.4)
        clip: true
        onTextChanged: tb.edited(text)
        onAccepted: { tb.committed(text); focus = false }
        onActiveFocusChanged: if (tb.commitOnBlur && !activeFocus && text !== tb.value) tb.committed(text)
        Keys.onEscapePressed: { text = tb.value; focus = false }

        Text {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: tb.placeholder
            font: input.font
            color: Colors.outline
        }
    }
}
