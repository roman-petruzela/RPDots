import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "Colors.js" as Colors

// Mod+Tab: „Alt+Tab pro workspacy“. Drž Mod, Tab listuje (Shift+Tab zpět),
// puštění Mod přepne. Workspacy jsou seřazené od naposledy použitého, takže
// rychlé Mod+Tab skáče tam a zpátky mezi dvěma posledními.
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
    readonly property int cardW: 232
    readonly property int screenH: Math.round(cardW * 9 / 16)
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
            const n = items.length
            selected = n > 1 ? (delta > 0 ? 1 : n - 1) : 0
            const fw = niri.focusedWorkspace()
            const scr = fw ? Quickshell.screens.find(s => s.name === fw.output) : null
            if (scr) screen = scr
            visible = true
        } else {
            selected = (selected + delta + items.length) % items.length
        }
        list.positionViewAtIndex(selected, ListView.Contain)
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
        const list = []
        for (const ws of Object.values(niri.workspaces)) {
            const ww = byWs[ws.id] || []
            // Prázdné workspacy (niri má vždy jeden na konci) nejsou kam přepnout
            if (ww.length === 0 && !ws.is_focused) continue
            const active = ww.find(w => w.id === ws.active_window_id)
            list.push({
                ws: ws,
                recent: ws.is_focused ? Infinity : Math.max(0, ...ww.map(w => niri.stamp(w))),
                label: ws.name ?? String(ws.idx),
                title: active ? (active.title || active.app_id) : "Empty",
                output: multiOutput ? niri.outputLabel(ws.output) : "",
                tiles: niri.minimap(ww, ws.active_window_id, ws.output, root.cardW, root.screenH)
            })
        }
        list.sort((a, b) => b.recent - a.recent)
        items = list
    }

    Rectangle {
        id: panel
        width: Math.min(list.contentWidth, (root.screen?.width ?? 1920) * 0.9) + 36
        height: list.height + 36
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

        ListView {
            id: list
            x: 18; y: 18
            width: parent.width - 36
            height: root.screenH + 52
            orientation: ListView.Horizontal
            spacing: 14
            interactive: false
            model: root.items

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool sel: index === root.selected

                width: root.cardW
                height: list.height

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
                        width: parent.width - num.width - 8
                        text: card.modelData.title
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        color: Colors.onSurfaceVariant
                    }
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
    }
}
