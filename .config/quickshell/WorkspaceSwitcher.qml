import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "Colors.js" as Colors

// Mod+Tab: „Alt+Tab pro workspacy“. Drž Mod, Tab listuje (Shift+Tab zpět),
// puštění Mod přepne. Karty jsou v pevném pořadí (monitor, pak číslo), výběr
// ale začíná na naposledy použitém workspace — rychlé Mod+Tab tak pořád
// skáče tam a zpátky mezi dvěma posledními.
//
// Tab při drženém Mod zpracuje niri (bind → `rp-shell workspaces next`), ne
// tohle okno — dostane jen puštění Mod. Když Mod pustíš dřív, než okno
// stihne získat klávesnici (extrémně rychlé ťuknutí), zůstane otevřené:
// pak Enter přepne, Esc zavře.
//
// Karta workspace je jeho minimapa: sloupce scrollovacího layoutu niri ve
// skutečném poměru šířek, s ikonou aplikace, na pozadí aktuální tapety.
PanelWindow {
    id: root

    required property var niri

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int cardW: 212
    readonly property int screenH: Math.round(cardW * 9 / 16)
    readonly property int cardH: screenH + 46
    readonly property int gap: 12
    // Mřížka max 7×3 jako Alt+Tab (WindowSwitcher); víc se posouvá po řádcích
    readonly property int cols: Math.max(1, Math.min(7, items.length,
        Math.floor(((screen?.width ?? 1920) * 0.9 - 36 + gap) / (cardW + gap))))
    readonly property int rows: Math.min(3, Math.ceil(items.length / cols))
    readonly property bool overflow: items.length > cols * rows
    // Zmenšená tapeta, kterou apply-wallpaper-theme.sh stejně dělá pro matugen
    readonly property string wallThumb: "file://" + Quickshell.env("HOME") + "/.cache/niri-rice/wal-matugen.png"

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

    function cycle(delta) {
        if (!visible) {
            build()
            if (items.length === 0) return
            // Začít na naposledy použitém workspace (ne na vedlejší kartě),
            // takže rychlé Mod+Tab pořád skáče tam a zpátky
            const prev = items.indexOf(items.filter(i => !i.ws.is_focused)
                .reduce((a, b) => (b.recent > (a?.recent ?? -1) ? b : a), null))
            selected = prev >= 0 ? prev : 0
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
        if (!it || it.ws.is_focused) return
        if (it.ws.active_window_id !== null && it.ws.active_window_id !== undefined)
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(it.ws.active_window_id)])
        else
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(it.ws.idx)])
    }

    // Snímek stavu při otevření — během listování se pořadí nemění, i když
    // mezitím niri pošle změny.
    function build() {
        const wins = Object.values(niri.windows)
        const byWs = {}
        for (const w of wins) (byWs[w.workspace_id] = byWs[w.workspace_id] || []).push(w)

        const multiOutput = new Set(Object.values(niri.workspaces).map(w => w.output)).size > 1
        const focusedOutput = niri.focusedWorkspace()?.output ?? ""
        const out = []
        for (const ws of Object.values(niri.workspaces)) {
            const ww = byWs[ws.id] || []
            // Prázdné workspacy (niri má vždy jeden na konci) nejsou kam přepnout
            if (ww.length === 0 && !ws.is_focused) continue
            const active = ww.find(w => w.id === ws.active_window_id)
            out.push({
                ws: ws,
                recent: Math.max(0, ...ww.map(w => niri.stamp(w))),
                label: ws.name ?? String(ws.idx),
                title: active ? (active.title || active.app_id) : "Empty",
                outputName: ws.output,
                output: multiOutput ? niri.outputLabel(ws.output) : "",
                tiles: niri.minimap(ww, ws.active_window_id, ws.output, root.cardW, root.screenH)
            })
        }
        // Pevné pořadí jako v niri: monitor, na kterém jsi, první, pak ostatní;
        // v rámci monitoru podle čísla. Karty tak mají pořád stejné místo.
        const outRank = o => o === focusedOutput ? "" : o
        out.sort((a, b) => outRank(a.outputName).localeCompare(outRank(b.outputName))
            || a.ws.idx - b.ws.idx)
        // Název monitoru jen na první kartě každého monitoru
        out.forEach((it, i) => {
            if (i > 0 && out[i - 1].outputName === it.outputName) it.output = ""
        })
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
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R
                    || event.key === Qt.Key_Meta) {
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

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool sel: index === root.selected

                width: root.cardW
                height: root.cardH

                ClippingRectangle {
                    id: scr
                    width: root.cardW
                    height: root.screenH
                    radius: 12
                    color: Colors.surface

                    Image {
                        anchors.fill: parent
                        source: root.wallThumb
                        sourceSize: Qt.size(root.cardW * 2, root.screenH * 2)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        opacity: 0.55
                    }

                    Minimap {
                        anchors.fill: parent
                        tiles: card.modelData.tiles
                        niri: root.niri
                    }

                    Text {
                        visible: card.modelData.output !== ""
                        anchors { left: parent.left; top: parent.top; margins: 6 }
                        text: card.modelData.output
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        color: Colors.onSurfaceVariant
                    }
                }

                Rectangle {
                    anchors.fill: scr
                    radius: scr.radius
                    color: "transparent"
                    border.width: card.sel ? 2 : 1
                    border.color: card.sel ? Colors.primary : Qt.alpha(Colors.onSurface, 0.12)
                }

                Row {
                    anchors { top: scr.bottom; topMargin: 10; left: parent.left; right: parent.right }
                    spacing: 8

                    // Tečka = workspace, na kterém právě jsi
                    Rectangle {
                        visible: card.modelData.ws.is_focused
                        anchors.verticalCenter: num.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: Colors.primary
                    }
                    Text {
                        id: num
                        text: card.modelData.label
                        font.family: root.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        color: card.sel ? Colors.primary : Colors.onSurface
                    }
                    Text {
                        anchors.baseline: num.baseline
                        width: parent.width - num.x - num.width - 8
                        text: card.modelData.title
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        color: Colors.onSurfaceVariant
                    }
                }

                HoverSelect {
                    anchors.fill: parent
                    onMoved: root.selected = card.index
                    onClicked: {
                        root.selected = card.index
                        root.commit()
                    }
                }
            }
        }

        // Posuvník a počitadlo jen když se workspacy nevejdou do 7×3
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
