import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import ".."
import "../Colors.js" as Colors

// Menu položky v tray, vykreslené v QML. SystemTrayItem.display() používá
// platformní (Qt Widgets) menu a to v quickshellu jde jen v režimu
// QApplication (pragma + restart) — a vypadalo by jako cizí okno. Tady:
// QsMenuOpener přečte položky přes DBusMenu, klik je `entry.triggered()`.
//
// Podmenu je tatáž komponenta, vysunutá vlevo od položky (najetím nebo klikem);
// vnoří se libovolně hluboko. Šířka podle nejdelší položky (měřená fontem).
// Zavření: klik na stejnou ikonu, Esc, nebo samo, když myš z menu (a jeho
// podmenu) odjede a do vteřiny se nevrátí. Klik mimo by měl zavřít
// grabFocus (xdg popup grab), jenže u popupu z panelu (vrstvy) to niri neudělá.
PopupWindow {
    id: menu

    property var menuHandle: null          // SystemTrayItem.menu nebo položka s podmenu
    property var parentMenu: null          // u podmenu menu, ze kterého vyjelo
    property Item owner: null              // ikona v tray (jen hlavní menu)
    property var subEntry: null            // položka, jejíž podmenu je otevřené
    // Položky, které podmenu měly (podle textu). nm-applet menu občas přestaví
    // a na chvíli u nich hlásí hasChildren = false — šipka by zmizela, sloupec
    // se zúžil a klik by místo podmenu spustil akci. Platí do dalšího otevření.
    property var subKeys: ({})
    function isSub(e) { return e.hasChildren || subKeys[e.text] === true }
    // Animace: `open` = má být vidět; při zavření se dohraje a pak visible = false
    property bool open: false

    readonly property bool isRoot: parentMenu === null
    // Myš je na menu nebo kdekoli v jeho otevřených podmenu
    readonly property bool treeHovered: selfHover.hovered
        || (sub.item !== null && sub.item.visible && sub.item.treeHovered)

    // Druhý klik na stejnou ikonu menu zavře
    function toggleAt(item, handle) {
        if (visible && open && owner === item) { dismiss(); return }
        owner = item
        subKeys = ({})
        menuHandle = handle
        anchor.item = item
        anchor.rect.x = item.width / 2 - implicitWidth / 2
        anchor.rect.y = item.height + 8
        show()
    }

    function show() { hideTimer.stop(); visible = true; open = true }
    function dismiss() { if (!visible) return; open = false; closeSub(); hideTimer.restart() }
    Timer { id: hideTimer; interval: 140; onTriggered: if (!menu.open) menu.visible = false }

    function closeAll() {
        if (parentMenu) parentMenu.closeAll()
        else dismiss()
    }

    function openSub(row, entry) {
        if (subEntry === entry && sub.item && sub.item.visible) return
        closeSub()
        sub.active = true
        const m = sub.item
        m.parentMenu = menu
        m.menuHandle = entry
        // Doleva od položky: tray je u pravého okraje obrazovky a vpravo by se
        // podmenu nevešlo — niri by ho posunul přes hlavní menu. Ukotvit k levé
        // hraně položky a růst doleva a dolů; kdyby nebylo místo ani tam, překlopit.
        m.anchor.item = row
        m.anchor.rect.x = -8
        m.anchor.rect.y = -4
        m.anchor.rect.width = 1
        m.anchor.rect.height = 1
        m.anchor.edges = Edges.Left | Edges.Top
        m.anchor.gravity = Edges.Left | Edges.Bottom
        m.anchor.adjustment = PopupAdjustment.FlipX | PopupAdjustment.SlideY
        m.subKeys = ({})
        m.show()
        subEntry = entry
    }

    function closeSub() {
        if (sub.item) sub.item.dismiss()
        subEntry = null
    }

    onVisibleChanged: if (!visible) { open = false; closeSub() }

    grabFocus: isRoot
    color: "transparent"
    visible: false

    // ── Rozměry
    readonly property int rowH: 28
    readonly property int fontSize: 13
    readonly property var entries: opener.children.values
    readonly property bool hasLead: entries.some(e => !e.isSeparator
        && (e.icon !== "" || e.buttonType !== QsMenuButtonType.None))
    readonly property bool hasSub: entries.some(e => isSub(e))
    readonly property real textW: Math.max(0, ...entries.filter(e => !e.isSeparator).map(e => fm.advanceWidth(clean(e.text))))
    implicitWidth: Math.ceil(Math.max(140, Math.min(460, textW + (hasLead ? 34 : 10) + (hasSub ? 22 : 0) + 30)))
    implicitHeight: col.implicitHeight + 8
    function clean(t) { return (t || "").replace(/_(?=[^_])/g, "") }      // mnemonic podtržítka pryč

    FontMetrics { id: fm; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: menu.fontSize }

    QsMenuOpener { id: opener; menu: menu.menuHandle }

    // Podmenu: tatáž komponenta (Loader, protože přímo sama sebe vnořit nejde)
    Loader { id: sub; active: false; source: "TrayMenu.qml" }

    // Hlavní menu se samo zavře, když myš opustí menu i podmenu a nevrátí se
    Timer { id: leaveClose; interval: 1000; onTriggered: if (!menu.treeHovered) menu.dismiss() }
    onTreeHoveredChanged: if (isRoot) { if (treeHovered) leaveClose.stop(); else leaveClose.restart() }

    // Podmenu se otevře po krátkém najetí (ne hned při přejezdu přes položku)
    property var hoverTarget: null
    Timer {
        id: hoverOpen
        interval: 180
        onTriggered: {
            const t = menu.hoverTarget
            if (!t) return
            if (menu.isSub(t.entry) && t.entry.enabled) menu.openSub(t.row, t.entry)
            else menu.closeSub()
        }
    }

    // Rozmazané pozadí jen pod otevřeným menu (jako BarPopup)
    BackgroundEffect.blurRegion: Region {
        width: menu.open ? body.width : 0
        height: menu.open ? body.height : 0
        radius: body.radius
    }

    // Vzhled a animace společné se všemi vyskakovacími kartami (PopupCard)
    PopupCard {
        id: body
        anchors.fill: parent
        shown: menu.open
        transformOrigin: Item.TopRight
        focus: true
        Keys.onEscapePressed: {
            if (menu.subEntry) menu.closeSub()
            else menu.dismiss()
        }
        HoverHandler { id: selfHover }

        Column {
            id: col
            x: 4; y: 4
            width: menu.implicitWidth - 8

            Repeater {
                model: opener.children
                Item {
                    id: row
                    required property var modelData
                    readonly property var e: modelData
                    readonly property bool subOpen: menu.subEntry === e
                    Component.onCompleted: remember()
                    Connections { target: row.e; function onHasChildrenChanged() { row.remember() } }
                    function remember() {
                        if (e.hasChildren && menu.subKeys[e.text] !== true) {
                            const k = Object.assign({}, menu.subKeys); k[e.text] = true; menu.subKeys = k
                        }
                    }
                    width: col.width
                    height: e.isSeparator ? 7 : menu.rowH

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
                        color: (rowHover.hovered || row.subOpen) && row.e.enabled ? Qt.alpha(Colors.primary, 0.16) : "transparent"
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
                            anchors { left: lead.right; leftMargin: menu.hasLead ? 8 : 9; right: arrow.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: menu.clean(row.e.text)
                            elide: Text.ElideRight
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: menu.fontSize
                            color: row.e.enabled ? Colors.onSurface : Qt.alpha(Colors.onSurface, 0.38)
                        }
                        Text {
                            id: arrow
                            visible: menu.isSub(row.e)
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: String.fromCodePoint(0xf0141)   // podmenu vyjíždí doleva
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: row.subOpen ? Colors.primary : Colors.onSurfaceVariant
                        }

                        HoverHandler {
                            id: rowHover
                            cursorShape: row.e.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onHoveredChanged: if (hovered) {
                                menu.hoverTarget = { row: row, entry: row.e }
                                hoverOpen.restart()
                            }
                        }
                        TapHandler {
                            enabled: row.e.enabled
                            onTapped: {
                                if (menu.isSub(row.e)) { menu.openSub(row, row.e); return }
                                row.e.triggered()
                                menu.closeAll()
                            }
                        }
                    }
                }
            }
        }
    }
}
