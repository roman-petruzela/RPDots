import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "Colors.js" as Colors

// Alt+Tab: přepínač oken ve stejném stylu jako Mod+Tab (WorkspaceSwitcher).
// Drž Alt, Tab listuje (Shift+Tab zpět), puštění Alt přepne. Alt+` ukáže jen
// okna stejné aplikace jako to zaostřené.
//
// Živé náhledy oken quickshell na niri nemá (screencopy jednotlivých oken
// niri nenabízí), karta proto místo nich ukazuje, kde okno leží: minimapu
// jeho workspace s tímhle oknem zvýrazněným.
PanelWindow {
    id: root

    required property var niri

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int cardW: 212
    readonly property int cardH: 162
    readonly property int gap: 12
    // Mřížka max 7×3; víc oken se posouvá po řádcích (grid.positionViewAtIndex)
    readonly property int cols: Math.max(1, Math.min(7, items.length,
        Math.floor(((screen?.width ?? 1920) * 0.9 - 36 + gap) / (cardW + gap))))
    readonly property int rows: Math.min(3, Math.ceil(items.length / cols))
    readonly property bool overflow: items.length > cols * rows
    readonly property int pad: 14
    readonly property int mapH: 40

    property var items: []
    property int selected: 0

    visible: false
    color: "transparent"
    implicitWidth: panel.width
    implicitHeight: panel.height

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rp-switcher"
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    function cycle(delta, sameApp) {
        if (!visible) {
            build(sameApp)
            if (items.length === 0) return
            const n = items.length
            selected = n > 1 ? (delta > 0 ? 1 : n - 1) : 0
            const fw = niri.focusedWorkspace()
            const scr = fw ? Quickshell.screens.find(s => s.name === fw.output) : null
            if (scr) screen = scr
            visible = true
        } else {
            selected = (selected + delta + items.length) % items.length
        }
        grid.positionViewAtIndex(selected, GridView.Contain)
    }

    function hide() { visible = false }

    function commit() {
        const it = items[selected]
        visible = false
        if (!it || it.win.is_focused) return
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(it.win.id)])
    }

    // Snímek při otevření: od naposledy zaostřeného, pořadí se během listování nemění
    function build(sameApp) {
        let wins = Object.values(niri.windows)
        const focused = wins.find(w => w.is_focused)
        if (sameApp && focused) wins = wins.filter(w => w.app_id === focused.app_id)

        const byWs = {}
        for (const w of Object.values(niri.windows))
            (byWs[w.workspace_id] = byWs[w.workspace_id] || []).push(w)
        const multiOutput = new Set(Object.values(niri.workspaces).map(w => w.output)).size > 1

        const out = wins.map(w => {
            const ws = niri.workspaces[w.workspace_id]
            return {
                win: w,
                recent: w.is_focused ? Infinity : niri.stamp(w),
                app: niri.appName(w.app_id ?? ""),
                icon: niri.appIcon(w.app_id ?? ""),
                title: w.title || "",
                where: ws ? "Workspace " + (ws.name ?? ws.idx) : "",
                output: multiOutput && ws ? niri.outputLabel(ws.output) : "",
                tiles: ws ? niri.minimap(byWs[ws.id] || [], w.id, ws.output, root.cardW - 2 * root.pad, root.mapH) : []
            }
        })
        out.sort((a, b) => b.recent - a.recent)
        items = out
    }

    Rectangle {
        id: panel
        // Buňky mřížky v sobě mají mezeru i za posledním sloupcem/řádkem
        width: grid.width - root.gap + 36 + (root.overflow ? 12 : 0)
        height: grid.height - root.gap + 36 + (root.overflow ? 16 : 0)
        radius: 22
        color: Qt.alpha(Colors.surfaceContainer, 0.78)
        border.color: Qt.alpha(Colors.outlineVariant, 0.8)
        border.width: 1

        focus: root.visible
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Tab:
            case Qt.Key_Right:   root.cycle(1); break
            case Qt.Key_Backtab:
            case Qt.Key_Left:    root.cycle(-1); break
            case Qt.Key_Down:    root.cycle(root.cols); break
            case Qt.Key_Up:      root.cycle(-root.cols); break
            case Qt.Key_Return:
            case Qt.Key_Enter:   root.commit(); break
            case Qt.Key_Escape:  root.hide(); break
            default: return
            }
            event.accepted = true
        }
        // Tab při drženém Alt jde do niri (bind → rp-shell), sem dorazí jen
        // puštění Alt. Pustíš-li ho dřív, než okno dostane klávesnici, zůstane
        // přepínač otevřený a přepne Enter.
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr) {
                root.commit()
                event.accepted = true
            }
        }

        WheelHandler {
            onWheel: event => root.cycle(event.angleDelta.y > 0 ? -root.cols : root.cols)
        }

        GridView {
            id: grid
            x: 18; y: 18
            width: root.cols * cellWidth
            height: root.rows * cellHeight
            cellWidth: root.cardW + root.gap
            cellHeight: root.cardH + root.gap
            interactive: false
            clip: true
            model: root.items

            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool sel: index === root.selected

                width: root.cardW
                height: root.cardH
                radius: 16
                color: card.sel
                    ? Qt.alpha(Colors.surfaceContainerHighest, 0.95)
                    : Qt.alpha(Colors.surfaceContainerHigh, 0.5)
                border.width: card.sel ? 2 : 1
                border.color: card.sel ? Colors.primary : Qt.alpha(Colors.onSurface, 0.08)

                Row {
                    id: head
                    x: root.pad; y: root.pad
                    width: parent.width - 2 * root.pad
                    spacing: 10

                    IconImage {
                        implicitSize: 36
                        source: card.modelData.icon
                    }

                    Column {
                        width: parent.width - 46
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: card.modelData.app
                            elide: Text.ElideRight
                            font.family: root.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: card.sel ? Colors.primary : Colors.onSurface
                        }
                        Row {
                            spacing: 8
                            Text {
                                text: card.modelData.where
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                color: Colors.onSurfaceVariant
                            }
                            Text {
                                visible: text !== ""
                                text: card.modelData.output
                                font.family: root.fontFamily
                                font.pixelSize: 11
                                color: Qt.alpha(Colors.onSurfaceVariant, 0.7)
                            }
                        }
                    }
                }

                Text {
                    anchors { top: head.bottom; topMargin: 10; left: parent.left; right: parent.right
                              leftMargin: root.pad; rightMargin: root.pad }
                    text: card.modelData.title
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    lineHeight: 1.15
                    color: Qt.alpha(Colors.onSurface, 0.82)
                }

                Minimap {
                    x: root.pad
                    y: parent.height - root.pad - root.mapH
                    width: parent.width - 2 * root.pad
                    height: root.mapH
                    tiles: card.modelData.tiles
                    niri: root.niri
                    icons: false
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selected = card.index
                    onClicked: {
                        root.selected = card.index
                        root.commit()
                    }
                }
            }
        }

        // Posuvník a počitadlo jen když se okna nevejdou do 7×3
        Rectangle {
            visible: root.overflow
            x: grid.x + grid.width - root.gap + 8
            y: grid.y
            width: 3
            height: grid.height - root.gap
            radius: 1.5
            color: Qt.alpha(Colors.onSurface, 0.1)

            Rectangle {
                width: parent.width
                radius: parent.radius
                color: Qt.alpha(Colors.primary, 0.8)
                height: Math.max(12, parent.height * grid.height / Math.max(grid.contentHeight, 1))
                y: (parent.height - height) * grid.contentY
                    / Math.max(grid.contentHeight - grid.height, 1)
            }
        }

        Text {
            visible: root.overflow
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 20; bottomMargin: 10 }
            text: (root.selected + 1) + " / " + root.items.length
            font.family: root.fontFamily
            font.pixelSize: 11
            color: Colors.onSurfaceVariant
        }
    }
}
