import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "Colors.js" as Colors

// Spouštěč aplikací (Mod+D), náhrada fuzzelu ve stylu ostatních oken rice.
// Prázdné pole ukáže naposledy spuštěné aplikace; psaní filtruje podle názvu,
// obecného názvu, klíčových slov a popisu. Příklad jako `12*7+3` se spočítá
// a Enter výsledek zkopíruje.
//
// Pořadí posledních spuštění se ukládá do ~/.cache/niri-rice/launcher-recent.json.
PanelWindow {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int rowH: 54
    readonly property int maxRows: 8

    property var recent: []          // id aplikací, nejnovější první
    property var results: []
    property int selected: 0

    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rp-overlay"
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    FocusedOutput { id: opener; window: root }

    function open() {
        input.text = ""
        refresh()
        opener.show()
    }

    function toggle() {
        if (visible) visible = false
        else open()
    }

    FileView {
        id: recentFile
        path: Quickshell.env("HOME") + "/.cache/niri-rice/launcher-recent.json"
        // Před prvním spuštěním aplikace soubor ještě neexistuje
        printErrors: false
        onLoaded: {
            try { root.recent = JSON.parse(text()) } catch (e) { root.recent = [] }
        }
    }

    // Seznam aplikací se načítá asynchronně (a mění se po instalaci) — když
    // je launcher otevřený dřív, než je hotový, doplní se výsledky dodatečně
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            if (root.visible) root.refresh()
        }
    }

    // --------------------------------------------------------------- search

    // Jednoduchá kalkulačka: jen čísla a operátory, takže eval je bezpečný
    function calc(q) {
        const expr = q.replace(/,/g, ".").replace(/\^/g, "**").replace(/×/g, "*")
        if (!/^[\d\s.+\-*/()%]+$/.test(expr) || !/\d\s*[-+*/%]/.test(expr)) return null
        try {
            const v = Function("\"use strict\"; return (" + expr + ")")()
            if (typeof v !== "number" || !isFinite(v)) return null
            return String(Math.round(v * 1e10) / 1e10)
        } catch (e) {
            return null
        }
    }

    function score(app, q) {
        const name = (app.name || "").toLowerCase()
        if (name.startsWith(q)) return 100
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80
        if (name.includes(q)) return 60
        const generic = (app.genericName || "").toLowerCase()
        if (generic.includes(q)) return 45
        if ((app.keywords || []).some(k => k.toLowerCase().startsWith(q))) return 40
        if ((app.comment || "").toLowerCase().includes(q)) return 20
        // Písmena ve správném pořadí ("ffx" → Firefox)
        let i = 0
        for (const c of name) if (c === q[i]) i++
        return i === q.length ? 10 : 0
    }

    function refresh() {
        const q = input.text.trim().toLowerCase()
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
        const rank = id => {
            const i = root.recent.indexOf(id)
            return i < 0 ? 0 : 20 - Math.min(i, 19)
        }
        let out
        if (q === "") {
            out = apps.slice().sort((a, b) =>
                rank(b.id) - rank(a.id) || a.name.localeCompare(b.name))
        } else {
            out = apps.map(a => ({ a, s: score(a, q) }))
                .filter(x => x.s > 0)
                .sort((x, y) => (y.s + rank(y.a.id) / 4) - (x.s + rank(x.a.id) / 4)
                    || x.a.name.localeCompare(y.a.name))
                .map(x => x.a)
        }
        const rows = out.slice(0, 60).map(a => ({
            kind: "app", app: a, title: a.name,
            sub: a.genericName && a.genericName !== a.name ? a.genericName : (a.comment || ""),
            icon: root.appIcon(a.icon)
        }))
        const result = calc(q)
        if (result !== null)
            rows.unshift({ kind: "calc", title: "= " + result, value: result,
                           sub: "Enter copies the result", icon: "" })
        results = rows
        selected = 0
        list.positionViewAtBeginning()
    }

    // iconPath(name, fallback) náhradu nepoužije, když ikona v tématu jen chybí
    // (vykreslí šachovnici) — check=true vrátí pro chybějící prázdný řetězec
    function appIcon(name) {
        return (name ? Quickshell.iconPath(name, true) : "")
            || Quickshell.iconPath("application-x-executable")
    }

    function activate(i) {
        const r = results[i]
        if (!r) return
        visible = false
        if (r.kind === "calc") {
            Quickshell.execDetached(["wl-copy", r.value])
            return
        }
        if (r.app.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(r.app.command))
        else r.app.execute()

        recent = [r.app.id].concat(recent.filter(id => id !== r.app.id)).slice(0, 30)
        recentFile.setText(JSON.stringify(recent))
    }

    function move(delta) {
        if (results.length === 0) return
        selected = Math.max(0, Math.min(results.length - 1, selected + delta))
        list.positionViewAtIndex(selected, ListView.Contain)
    }

    // ------------------------------------------------------------------- ui

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.background, 0.3)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.2)
        width: 660
        height: field.height + (root.results.length > 0 ? list.height + 22 : 0) + 24
        radius: 26
        color: Qt.alpha(Colors.surfaceContainer, 0.86)
        border.color: Qt.alpha(Colors.outlineVariant, 0.8)
        border.width: 1

        // Klik do panelu nesmí propadnout na zavírací vrstvu
        MouseArea { anchors.fill: parent }

        Rectangle {
            id: field
            x: 12; y: 12
            width: parent.width - 24
            height: 58
            radius: 18
            color: Qt.alpha(Colors.surfaceContainerHighest, 0.9)

            Text {
                id: glyph
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: ""
                font.family: root.fontFamily
                font.pixelSize: 18
                color: Colors.primary
            }

            TextInput {
                id: input
                anchors {
                    left: glyph.right; leftMargin: 16; right: parent.right; rightMargin: 20
                    verticalCenter: parent.verticalCenter
                }
                focus: root.visible
                font.family: root.fontFamily
                font.pixelSize: 20
                color: Colors.onSurface
                selectionColor: Qt.alpha(Colors.primary, 0.4)
                clip: true
                onTextChanged: root.refresh()

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                            || (ctrl && event.key === Qt.Key_N)) root.move(1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                            || (ctrl && event.key === Qt.Key_P)) root.move(-1)
                    else if (event.key === Qt.Key_PageDown) root.move(root.maxRows)
                    else if (event.key === Qt.Key_PageUp) root.move(-root.maxRows)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate(root.selected)
                    else if (event.key === Qt.Key_Escape) root.visible = false
                    else return
                    event.accepted = true
                }

                Text {
                    visible: input.text === ""
                    text: "Search apps, or type a sum"
                    font: input.font
                    color: Qt.alpha(Colors.onSurfaceVariant, 0.6)
                }
            }
        }

        ListView {
            id: list
            x: 12
            anchors.top: field.bottom
            anchors.topMargin: 10
            width: parent.width - 24
            height: Math.min(root.results.length, root.maxRows) * root.rowH
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.results

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === root.selected

                width: list.width
                height: root.rowH
                radius: 14
                color: sel ? Qt.alpha(Colors.surfaceContainerHighest, 0.95) : "transparent"
                border.width: sel ? 1 : 0
                border.color: Qt.alpha(Colors.primary, 0.7)

                IconImage {
                    id: icon
                    visible: row.modelData.icon !== ""
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    implicitSize: 32
                    source: row.modelData.icon
                }

                Column {
                    anchors {
                        left: parent.left; leftMargin: 62; right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Text {
                        width: parent.width
                        text: row.modelData.title
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 15
                        font.weight: row.modelData.kind === "calc" ? Font.DemiBold : Font.Medium
                        color: row.sel ? Colors.primary : Colors.onSurface
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.sub
                        elide: Text.ElideRight
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        color: Colors.onSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selected = row.index
                    onClicked: root.activate(row.index)
                }
            }
        }
    }
}
