import Quickshell
import Quickshell.Widgets
import QtQuick
import "../Colors.js" as Colors

// Menu položky v tray, vykreslené v QML. SystemTrayItem.display() používá
// platformní (Qt Widgets) menu a to v quickshellu jde jen v režimu
// QApplication (pragma + restart) — a vypadalo by jako cizí okno. Tady:
// QsMenuOpener přečte položky přes DBusMenu, klik je `entry.triggered()`.
// Podmenu se otevře na místě (s řádkem Back), klik mimo menu ho zavře
// (grabFocus = xdg popup grab).
PopupWindow {
    id: menu

    property var rootMenu: null            // SystemTrayItem.menu
    property var stack: []                 // otevřená podmenu (QsMenuEntry)
    readonly property var current: stack.length ? stack[stack.length - 1] : rootMenu

    function openAt(item, menuHandle) {
        rootMenu = menuHandle
        stack = []
        anchor.item = item
        anchor.rect.x = item.width / 2 - implicitWidth / 2
        anchor.rect.y = item.height + 8
        visible = true
    }

    grabFocus: true
    color: "transparent"
    visible: false
    implicitWidth: Math.max(120, Math.min(320, col.implicitWidth + 8))
    implicitHeight: col.implicitHeight + 8
    readonly property int rowH: 24
    // Sloupec pro ikonu / zaškrtávátko jen když ho nějaká položka potřebuje
    readonly property bool hasLead: opener.children.values.some(e => !e.isSeparator
        && (e.icon !== "" || e.buttonType !== QsMenuButtonType.None))
    onVisibleChanged: if (!visible) stack = []

    QsMenuOpener { id: opener; menu: menu.current }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Qt.alpha(Colors.surfaceContainerHigh, 0.98)
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.9)

        Column {
            id: col
            x: 4; y: 4
            width: menu.implicitWidth - 8

            // Zpět z podmenu
            Rectangle {
                visible: menu.stack.length > 0
                width: parent.width; height: menu.rowH; radius: 6
                color: backHover.hovered ? Qt.alpha(Colors.primary, 0.14) : "transparent"
                HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: menu.stack = menu.stack.slice(0, -1) }
                Text {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: String.fromCodePoint(0xf0141) + " Back"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Colors.onSurfaceVariant
                }
            }

            Repeater {
                model: opener.children
                Item {
                    id: row
                    required property var modelData
                    readonly property var e: modelData
                    width: col.width
                    height: e.isSeparator ? 7 : menu.rowH
                    implicitWidth: e.isSeparator ? 0 : label.implicitWidth + (menu.hasLead ? 40 : 18) + (e.hasChildren ? 18 : 0)

                    Rectangle {
                        visible: row.e.isSeparator
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 6 }
                        height: 1
                        color: Qt.alpha(Colors.outlineVariant, 0.7)
                    }

                    Rectangle {
                        visible: !row.e.isSeparator
                        anchors.fill: parent
                        radius: 6
                        color: rowHover.hovered && row.e.enabled ? Qt.alpha(Colors.primary, 0.16) : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }

                        // Zaškrtávátko / přepínač, jinak ikona položky
                        Item {
                            id: lead
                            anchors { left: parent.left; leftMargin: menu.hasLead ? 6 : 0; verticalCenter: parent.verticalCenter }
                            visible: menu.hasLead
                            width: menu.hasLead ? 16 : 0; height: 16
                            Text {
                                visible: row.e.buttonType !== QsMenuButtonType.None
                                anchors.centerIn: parent
                                text: row.e.buttonType === QsMenuButtonType.RadioButton
                                    ? String.fromCodePoint(row.e.checkState === Qt.Checked ? 0xf0134 : 0xf0130)
                                    : String.fromCodePoint(row.e.checkState === Qt.Checked ? 0xf0132 : 0xf0131)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                color: row.e.checkState === Qt.Checked ? Colors.primary : Colors.onSurfaceVariant
                            }
                            IconImage {
                                visible: row.e.buttonType === QsMenuButtonType.None && row.e.icon !== ""
                                anchors.fill: parent
                                source: row.e.icon
                            }
                        }
                        Text {
                            id: label
                            anchors { left: lead.right; leftMargin: menu.hasLead ? 8 : 9; right: arrow.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: row.e.text.replace(/_(?=[^_])/g, "")       // mnemonic podtržítka pryč
                            elide: Text.ElideRight
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: row.e.enabled ? Colors.onSurface : Qt.alpha(Colors.onSurface, 0.38)
                        }
                        Text {
                            id: arrow
                            visible: row.e.hasChildren
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: String.fromCodePoint(0xf0142)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: Colors.onSurfaceVariant
                        }
                        HoverHandler { id: rowHover; cursorShape: row.e.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        TapHandler {
                            enabled: row.e.enabled
                            onTapped: {
                                if (row.e.hasChildren) { menu.stack = menu.stack.concat([row.e]); return }
                                row.e.triggered()
                                menu.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
