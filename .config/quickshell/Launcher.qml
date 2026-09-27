import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "Colors.js" as Colors

// Spouštěč aplikací (Mod+D), náhrada fuzzelu a schválně skoro jako on: malé
// okno uprostřed, 12 řádků, zvýrazněná shoda, stejné barvy.
// Prázdné pole ukáže naposledy spuštěné aplikace; psaní filtruje podle názvu,
// obecného názvu, klíčových slov a popisu. Příklad jako `12*7+3` se spočítá
// a Enter výsledek zkopíruje.
//
// Je to plovoucí okno (xdg toplevel) jako Settings, ne vrstva: otevření
// a zavření animuje niri stejně jako u Mod+S. Dřív to byla vrstva s vlastní
// animací (PopAnim) a blur za ní naskakoval skokem — za kartou problikl.
// Okno se při každém otevření vytvoří (LazyLoader) a při zavření zahodí, ať
// se niri zavírací animace přehraje a zavření přes Mod+Q ho nerozbije (viz
// Settings). Zavře se i kliknutím jinam (ztráta fokusu), jako fuzzel.
// window-rule v config.kdl (titulek „RPLauncher") ho otevře plovoucí.
//
// Pořadí posledních spuštění se ukládá do ~/.cache/niri-rice/launcher-recent.json.
Scope {
    id: outer

    // Stejné rozhraní jako dřív (shell.qml: visible = false, toggle(), hide())
    property bool visible: false
    function open()   { visible = true }
    function hide()   { visible = false }
    function toggle() { visible = !visible }

    LazyLoader {
        active: outer.visible

        FloatingWindow {
            id: root

            readonly property string fontFamily: "JetBrainsMono Nerd Font"
            readonly property int rowH: 34
            readonly property int maxRows: 12
            readonly property int pad: 12

            property var recent: []          // id aplikací, nejnovější první
            property var results: []
            property string query: ""
            property int selected: 0

            title: "RPLauncher"
            visible: true
            color: "transparent"
            // Pevná velikost (jako fuzzel `lines=12`); okno tak při psaní nemění
            // rozměry ani neposkakuje. Na střed ho dá niri (plovoucí okno).
            implicitWidth: 540
            implicitHeight: panel.height
            minimumSize: Qt.size(540, panel.height)
            maximumSize: Qt.size(540, panel.height)
            onClosed: outer.hide()

            BackgroundEffect.blurRegion: Region { item: panel; radius: 12 }

            function hide() { outer.hide() }

            Component.onCompleted: refresh()

            // Klik jinam (okno ztratí fokus) zavře launcher, jako fuzzel.
            // Window.active je attached vlastnost Qt Quick, quickshell ji sám nehlásí.
            Item {
                readonly property bool winActive: Window.active
                property bool wasActive: false
                onWinActiveChanged: {
                    if (winActive) wasActive = true
                    else if (wasActive) outer.hide()
                }
            }

            FileView {
                id: recentFile
                path: Quickshell.env("HOME") + "/.cache/niri-rice/launcher-recent.json"
                // Před prvním spuštěním aplikace soubor ještě neexistuje
                printErrors: false
                onLoaded: {
                    try { root.recent = JSON.parse(text()) } catch (e) { root.recent = [] }
                    // Soubor se načte až po prvním sestavení seznamu (okno je nové při
                    // každém otevření) — přepočítat, ať jsou poslední spuštěné nahoře
                    root.refresh()
                }
            }

            // Seznam aplikací se načítá asynchronně (a mění se po instalaci) — když
            // je launcher otevřený dřív, než je hotový, doplní se výsledky dodatečně
            Connections {
                target: DesktopEntries.applications
                function onValuesChanged() {
                    root.refresh()
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
                query = q
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
                const rows = out.map(a => ({
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
                hide()
                if (r.kind === "calc") {
                    Quickshell.execDetached(["wl-copy", r.value])
                    return
                }
                if (r.app.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(r.app.command))
                else r.app.execute()

                recent = [r.app.id].concat(recent.filter(id => id !== r.app.id)).slice(0, 30)
                recentFile.setText(JSON.stringify(recent))
            }

            // Název s obarvenou shodou (souvislý úsek, jinak jednotlivá písmena po řadě)
            function highlight(name, q) {
                const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                const mark = t => "<font color=\"" + Colors.primary + "\">" + esc(t) + "</font>"
                if (q === "") return esc(name)
                const i = name.toLowerCase().indexOf(q)
                if (i >= 0) return esc(name.slice(0, i)) + mark(name.slice(i, i + q.length)) + esc(name.slice(i + q.length))
                let out = "", j = 0
                for (const c of name) {
                    if (j < q.length && c.toLowerCase() === q[j]) { out += mark(c); j++ }
                    else out += esc(c)
                }
                return j === q.length ? out : esc(name)
            }

            function move(delta) {
                if (results.length === 0) return
                selected = Math.max(0, Math.min(results.length - 1, selected + delta))
                list.positionViewAtIndex(selected, ListView.Contain)
            }

            // ------------------------------------------------------------------- ui

            Rectangle {
                id: panel
                width: parent.width
                height: field.height + root.maxRows * root.rowH + 3 * root.pad
                radius: 12
                color: Qt.alpha(Colors.surfaceContainer, 0.9)
                border.color: Colors.outlineVariant
                border.width: 1

                Item {
                    id: field
                    x: root.pad + 8; y: root.pad
                    width: parent.width - 2 * root.pad - 16
                    height: 36

                    Text {
                        id: glyph
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "\uf002"
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        color: Colors.primary
                    }

                    TextInput {
                        id: input
                        anchors {
                            left: glyph.right; leftMargin: 12; right: counter.left; rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        focus: true
                        font.family: root.fontFamily
                        font.pixelSize: 16
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
                            else if (event.key === Qt.Key_Escape) root.hide()
                            else return
                            event.accepted = true
                        }

                        Text {
                            visible: input.text === ""
                            text: "Search apps, or type a sum"
                            font: input.font
                            color: Colors.outline
                        }
                    }

                    Text {
                        id: counter
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: root.results.length
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        color: Colors.outline
                    }
                }

                ListView {
                    id: list
                    x: root.pad
                    y: field.y + field.height + root.pad
                    width: parent.width - 2 * root.pad
                    height: root.maxRows * root.rowH
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
                        radius: 8
                        color: sel ? Colors.primaryContainer : "transparent"

                        IconImage {
                            id: icon
                            visible: row.modelData.icon !== ""
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            implicitSize: 22
                            source: row.modelData.icon
                        }

                        Text {
                            anchors {
                                left: parent.left; leftMargin: 42; right: parent.right; rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            textFormat: row.modelData.kind === "calc" ? Text.PlainText : Text.StyledText
                            text: row.modelData.kind === "calc" ? row.modelData.title
                                : root.highlight(row.modelData.title, root.query)
                            elide: Text.ElideRight
                            font.family: root.fontFamily
                            font.pixelSize: 15
                            font.weight: row.modelData.kind === "calc" ? Font.DemiBold : Font.Normal
                            color: row.sel ? Colors.onPrimaryContainer : Colors.onSurface
                        }

                        HoverSelect {
                            anchors.fill: parent
                            onMoved: root.selected = row.index
                            onClicked: root.activate(row.index)
                        }
                    }
                }
            }
        }
    }
}
