import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Monitory: náhled rozložení (přetažením se monitor přesune a přichytí
// k nejbližší hraně jiného), a pro vybraný monitor zapnutí, režim, škála,
// otočení a VRR. Všechno přes `rp-display set`, které změnu hned aplikuje
// a uloží do niri configu i do profilu kanshi (jinak by ji kanshi při
// dalším připojení monitoru vrátil).
Item {
    id: page
    required property var host

    property var outputs: []
    property string selected: ""
    readonly property var sel: outputs.find(o => o.name === selected) ?? outputs[0] ?? null

    function reload() {
        listProc.running = false
        listProc.running = true
    }

    function set(key, value) {
        host.job.start("Display " + sel.name + ": " + key + " → " + value,
                       ["rp-display", "set", sel.name, key, String(value)], [],
                       code => { page.reload(); if (code === 0) page.host.job.open = false })
    }

    Component.onCompleted: reload()

    Process {
        id: listProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-display", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.outputs = JSON.parse(text)
                    if (!page.outputs.find(o => o.name === page.selected) && page.outputs.length)
                        page.selected = page.outputs[0].name
                } catch (e) { page.host.showError("rp-display list failed") }
            }
        }
    }

    // Rozměry náhledu: všechny zapnuté monitory se vejdou do plochy
    readonly property var bounds: {
        const on = outputs.filter(o => o.enabled)
        if (on.length === 0) return { x: 0, y: 0, w: 1, h: 1 }
        const x0 = Math.min(...on.map(o => o.x)), y0 = Math.min(...on.map(o => o.y))
        const x1 = Math.max(...on.map(o => o.x + o.width)), y1 = Math.max(...on.map(o => o.y + o.height))
        return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
    }

    // Po puštění: přichytit k nejbližší hraně jiného monitoru (vedle / nad / pod)
    function snap(o, nx, ny) {
        let best = null
        for (const t of outputs.filter(p => p.enabled && p.name !== o.name)) {
            const cands = [
                { x: t.x - o.width, y: t.y },          // vlevo, zarovnat nahoru
                { x: t.x + t.width, y: t.y },          // vpravo
                { x: t.x, y: t.y - o.height },         // nad
                { x: t.x, y: t.y + t.height },         // pod
                { x: t.x - o.width, y: t.y + t.height - o.height },   // vlevo, zarovnat dolů
                { x: t.x + t.width, y: t.y + t.height - o.height },   // vpravo, zarovnat dolů
            ]
            for (const c of cands) {
                const d = Math.hypot(c.x - nx, c.y - ny)
                if (!best || d < best.d) best = { x: c.x, y: c.y, d }
            }
        }
        return best ?? { x: nx, y: ny }
    }

    readonly property var scales: [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3]
    readonly property var transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]

    SWheel { flick: flick }
    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}

        Column {
            id: col
            width: flick.width - 12
            spacing: 2
            topPadding: 8

            // ── Náhled rozložení
            SCard {
                id: preview
                width: parent.width
                height: 250

                readonly property real pad: 30
                readonly property real k: Math.min((width - 2 * pad) / page.bounds.w, (height - 2 * pad - 30) / page.bounds.h)
                readonly property real ox: (width - page.bounds.w * k) / 2
                readonly property real oy: (height - 30 - page.bounds.h * k) / 2

                Repeater {
                    model: page.outputs.filter(o => o.enabled)
                    Rectangle {
                        id: mon
                        required property var modelData
                        readonly property bool isSel: modelData.name === page.sel?.name
                        x: preview.ox + (modelData.x - page.bounds.x) * preview.k
                        y: preview.oy + (modelData.y - page.bounds.y) * preview.k
                        width: modelData.width * preview.k
                        height: modelData.height * preview.k
                        radius: 8
                        color: isSel ? Qt.alpha(Colors.primary, 0.28) : Qt.alpha(Colors.surfaceContainerHighest, 0.9)
                        border.width: isSel ? 2 : 1
                        border.color: isSel ? Colors.primary : Colors.outlineVariant
                        z: drag.active ? 2 : 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            SLabel {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: mon.modelData.name
                                font.weight: Font.DemiBold
                            }
                            SHint {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: mon.modelData.model
                                wrapMode: Text.NoWrap
                            }
                        }

                        DragHandler {
                            id: drag
                            enabled: page.outputs.filter(o => o.enabled).length > 1
                            onActiveChanged: {
                                if (active) { page.selected = mon.modelData.name; return }
                                // Zpět na logické souřadnice a přichytit
                                const nx = Math.round((mon.x - preview.ox) / preview.k + page.bounds.x)
                                const ny = Math.round((mon.y - preview.oy) / preview.k + page.bounds.y)
                                const p = page.snap(mon.modelData, nx, ny)
                                if (p.x !== mon.modelData.x || p.y !== mon.modelData.y) {
                                    page.selected = mon.modelData.name
                                    page.set("position", p.x + "," + p.y)
                                } else {
                                    page.reload()   // vrátit obdélník na místo
                                }
                            }
                        }
                        TapHandler { onTapped: page.selected = mon.modelData.name }
                    }
                }

                Row {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 14 }
                    spacing: 8
                    SHint { anchors.verticalCenter: parent.verticalCenter; text: "Drag to arrange. Click to select."; wrapMode: Text.NoWrap }
                }
                Row {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                    spacing: 8
                    SButton { icon: "󰍹"; text: "Identify"; onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rp-display", "identify"]) }
                    SButton { icon: "󰑓"; text: ""; onClicked: page.reload() }
                }
            }

            // Výběr monitoru (i vypnutých — ty v náhledu nejsou)
            Item { width: 1; height: 8 }
            Row {
                spacing: 8
                leftPadding: 14
                Repeater {
                    model: page.outputs
                    SChip {
                        required property var modelData
                        text: modelData.name + (modelData.enabled ? "" : " (off)")
                        selected: modelData.name === page.sel?.name
                        onClicked: page.selected = modelData.name
                    }
                }
            }

            // ── Nastavení vybraného
            SHeading { text: page.sel ? (page.sel.make + " " + page.sel.model).toUpperCase() : "" }
            SRow {
                label: "Use this display"
                hint: "The last display that's on can't be turned off."
                SToggle {
                    checked: page.sel?.enabled ?? false
                    onToggled: v => page.set("enabled", v ? "true" : "false")
                }
            }
            SRow {
                visible: page.sel?.enabled ?? false
                label: "Resolution & refresh rate"
                hint: "★ marks the display's preferred mode."
                SDropdown {
                    width: 280
                    options: page.sel ? page.sel.modes.map(m => m.spec) : []
                    labels: page.sel ? page.sel.modes.map(m => m.label + (m.preferred ? "  ★" : "")) : []
                    current: page.sel?.mode ?? ""
                    // Aktuální režim nemusí být přesně stejný řetězec (zaokrouhlení) — vybrat podle rozměrů a Hz
                    displayText: {
                        const s = page.sel
                        if (!s) return ""
                        const m = s.modes.find(m => m.spec === s.mode)
                            ?? s.modes.find(m => s.mode && s.mode.startsWith(m.width + "x" + m.height + "@" + Math.floor(m.refresh)))
                        return m ? m.label : (s.mode ?? "")
                    }
                    onPicked: v => page.set("mode", v)
                }
            }
            SRow {
                visible: page.sel?.enabled ?? false
                label: "Scale"
                hint: "Size of everything on this display."
                SDropdown {
                    width: 160
                    options: page.scales.map(String)
                    labels: page.scales.map(s => Math.round(s * 100) + "%")
                    current: String(page.sel?.scale ?? 1)
                    onPicked: v => page.set("scale", v)
                }
            }
            SRow {
                visible: page.sel?.enabled ?? false
                label: "Orientation"
                SDropdown {
                    width: 200
                    options: page.transforms
                    labels: ["Normal", "90°", "180°", "270°", "Flipped", "Flipped 90°", "Flipped 180°", "Flipped 270°"]
                    current: page.sel?.transform ?? "normal"
                    onPicked: v => page.set("transform", v)
                }
            }
            SRow {
                visible: (page.sel?.enabled ?? false) && (page.sel?.vrrSupported ?? false)
                label: "Variable refresh rate"
                hint: "On demand: only for windows with the VRR window rule (games)."
                SSegmented {
                    options: ["off", "on-demand", "on"]
                    labels: ["Off", "On demand", "Always"]
                    current: page.sel?.vrr ?? "off"
                    onPicked: v => page.set("vrr", v)
                }
            }
            SRow {
                visible: page.sel?.enabled ?? false
                label: "Position"
                hint: "Logical pixels; drag in the preview instead if you like."
                SMono {
                    text: page.sel ? page.sel.x + ", " + page.sel.y + "   ·   " + page.sel.width + "×" + page.sel.height + " logical" : ""
                    color: Colors.onSurface
                }
            }

            SHint {
                width: parent.width
                leftPadding: 14; rightPadding: 14; topPadding: 12
                text: "Changes apply right away and are saved to ~/.config/niri/displays.kdl and the matching kanshi profile."
            }
        }
    }
}
