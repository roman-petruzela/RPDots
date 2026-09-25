import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

// Historie schránky (Mod+Ctrl+V), vzhledem stejná jako Launcher (fuzzel-like
// okno uprostřed). Data drží cliphist (niri-rice-cliphist.service ukládá každý
// nový výběr). Psaní filtruje, Enter položku zkopíruje zpátky do schránky
// (vložíš Ctrl+V), Shift+Delete ji z historie smaže.
//
// Obrázky mají náhled: dekódují se až pro řádky, které se opravdu vykreslí,
// do $XDG_RUNTIME_DIR/rp-clip (tmpfs, maže se při každém otevření).
PanelWindow {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int rowH: 34
    readonly property int imageRowH: 62
    readonly property int listH: 12 * rowH
    readonly property int pad: 12
    readonly property string thumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/rp-clip"

    property var entries: []     // { id, line, text, image, meta }
    property var results: []
    property int selected: 0
    property bool missing: false // cliphist není nainstalovaný

    visible: false
    color: "transparent"
    implicitWidth: 560
    implicitHeight: panel.height
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Stejný namespace jako fuzzel/Launcher → stejný blur se zaoblením z niri
    WlrLayershell.namespace: "launcher"
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    FocusedOutput { id: opener; window: root }

    function open() {
        input.text = ""
        entries = []
        results = []
        lister.running = false
        lister.running = true
        opener.show()
    }

    function toggle() {
        if (visible) visible = false
        else open()
    }

    Process {
        id: lister
        command: ["sh", "-c", "rm -rf \"$1\"; mkdir -p \"$1\"; exec cliphist list", "sh", root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab < 0) continue
                    const body = line.slice(tab + 1)
                    // "[[ binary data 45 KiB png 1920x1080 ]]"
                    const m = body.match(/^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/)
                    out.push({
                        id: line.slice(0, tab),
                        line: line,
                        text: m ? "" : body,
                        image: !!m,
                        meta: m ? m[2].toUpperCase() + "  " + m[3].replace("x", "×") + "  " + m[1] : ""
                    })
                }
                root.entries = out
                root.filter()
            }
        }
        onExited: code => root.missing = code !== 0 && root.entries.length === 0
    }

    function filter() {
        const q = input.text.trim().toLowerCase()
        results = q === "" ? entries
            : entries.filter(e => (e.image ? "image " + e.meta : e.text).toLowerCase().includes(q))
        selected = 0
        list.positionViewAtBeginning()
    }

    function activate(i) {
        const e = results[i]
        if (!e) return
        visible = false
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", e.id])
    }

    function remove(i) {
        const e = results[i]
        if (!e) return
        // cliphist delete bere celý řádek z `list` na stdin
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", e.line])
        entries = entries.filter(x => x.id !== e.id)
        const keep = Math.min(selected, results.length - 2)
        filter()
        selected = Math.max(0, keep)
    }

    function move(delta) {
        if (results.length === 0) return
        selected = Math.max(0, Math.min(results.length - 1, selected + delta))
        list.positionViewAtIndex(selected, ListView.Contain)
    }

    Rectangle {
        id: panel
        width: parent.width
        height: field.height + root.listH + 3 * root.pad
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
                text: ""   // FontAwesome clipboard
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
                focus: root.visible
                font.family: root.fontFamily
                font.pixelSize: 16
                color: Colors.onSurface
                selectionColor: Qt.alpha(Colors.primary, 0.4)
                clip: true
                onTextChanged: root.filter()

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab
                            || (ctrl && event.key === Qt.Key_N)) root.move(1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                            || (ctrl && event.key === Qt.Key_P)) root.move(-1)
                    else if (event.key === Qt.Key_PageDown) root.move(10)
                    else if (event.key === Qt.Key_PageUp) root.move(-10)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate(root.selected)
                    else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) root.remove(root.selected)
                    else if (event.key === Qt.Key_Escape) root.visible = false
                    else return
                    event.accepted = true
                }

                Text {
                    visible: input.text === ""
                    text: "Search clipboard history"
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

        Text {
            anchors.centerIn: list
            visible: root.results.length === 0 && !lister.running
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.3
            text: root.missing
                ? "Clipboard history needs cliphist.\nInstall it: sudo pacman -S cliphist"
                : input.text !== "" ? "Nothing in the history matches."
                : "The history is empty.\nCopied text and images will show up here."
            font.family: root.fontFamily
            font.pixelSize: 14
            color: Colors.onSurfaceVariant
        }

        ListView {
            id: list
            x: root.pad
            y: field.y + field.height + root.pad
            width: parent.width - 2 * root.pad
            height: root.listH
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.results

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === root.selected
                readonly property string thumb: root.thumbDir + "/" + modelData.id + ".img"

                width: list.width
                height: modelData.image ? root.imageRowH : root.rowH
                radius: 8
                color: sel ? Colors.primaryContainer : "transparent"

                // Náhled obrázku: dekódovat, až je řádek vykreslený
                Process {
                    id: decoder
                    running: row.modelData.image
                    command: ["sh", "-c", "[ -s \"$2\" ] || cliphist decode \"$1\" > \"$2\"", "sh",
                              row.modelData.id, row.thumb]
                    onExited: thumbImg.source = "file://" + row.thumb
                }

                Rectangle {
                    id: thumbBox
                    visible: row.modelData.image
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 84
                    height: root.imageRowH - 12
                    radius: 6
                    color: Qt.alpha(Colors.surfaceContainerHighest, 0.8)
                    clip: true

                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(168, 100)
                    }
                }

                Text {
                    anchors {
                        left: row.modelData.image ? thumbBox.right : parent.left
                        leftMargin: row.modelData.image ? 14 : 12
                        right: parent.right; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    // Víceřádkový text zobrazit na jednom řádku
                    text: row.modelData.image ? row.modelData.meta
                        : row.modelData.text.replace(/\s+/g, " ").trim()
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: root.fontFamily
                    font.pixelSize: row.modelData.image ? 13 : 15
                    color: row.sel ? Colors.onPrimaryContainer
                        : row.modelData.image ? Colors.onSurfaceVariant : Colors.onSurface
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
