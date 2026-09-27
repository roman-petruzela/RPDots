import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property var binds: []
    property string query: ""
    property string capturing: ""
    property string newKey: ""
    property string newAction: "spawn"
    property string newArgs: ""

    function reload() {
        listProc.running = false
        listProc.running = true
    }

    function keys(args, title) {
        host.job.start(title, ["rp-keys"].concat(args), [],
                       code => { page.reload(); if (code === 0) page.host.job.open = false })
    }

    Component.onCompleted: reload()

    Process {
        id: listProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-keys", "list"]
        stdout: StdioCollector {
            onStreamFinished: { try { page.binds = JSON.parse(text) } catch (e) { page.host.showError("rp-keys list failed") } }
        }
    }

    ShortcutInhibitor {
        window: page.host
        enabled: page.capturing !== ""
    }

    function category(b) {
        const a = b.action
        if (a === "spawn" || a === "spawn-sh") return "Apps & scripts"
        if (/workspace/.test(a)) return "Workspaces"
        if (/monitor/.test(a)) return "Monitors"
        if (/^focus|overview/.test(a)) return "Focus"
        if (/^move|consume|expel|swap/.test(a)) return "Move windows"
        if (/width|height|size|maximize|fullscreen|column|floating|tabbed|reset/.test(a)) return "Window size & layout"
        if (/screenshot/.test(a)) return "Screenshots"
        return "Session & other"
    }

    function describe(b) {
        if (b.title) return b.title
        const args = b.args.replace(/"/g, "").replace(/~\/\.local\/bin\//g, "")
        const act = b.action.replace(/-/g, " ")
        return act.charAt(0).toUpperCase() + act.slice(1) + (args ? ": " + args : "")
    }

    readonly property var shown: {
        const q = query.trim().toLowerCase()
        return binds.filter(b => q === "" || (b.key + " " + b.action + " " + b.args + " " + b.title).toLowerCase().includes(q))
    }

    readonly property var groups: {
        const order = ["Apps & scripts", "Focus", "Move windows", "Window size & layout", "Workspaces",
                       "Monitors", "Screenshots", "Session & other"]
        const g = {}
        for (const b of shown) (g[category(b)] = g[category(b)] || []).push(b)
        return order.filter(k => g[k]).map(k => ({ title: k, items: g[k] }))
    }

    function keyName(e) {
        const k = e.key
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1)
        const map = {
            [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Escape]: "Escape", [Qt.Key_Tab]: "Tab",
            [Qt.Key_Backtab]: "Tab", [Qt.Key_Space]: "Space", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete",
            [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
            [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down",
            [Qt.Key_Print]: "Print", [Qt.Key_Comma]: "Comma", [Qt.Key_Period]: "Period", [Qt.Key_Slash]: "Slash",
            [Qt.Key_Minus]: "Minus", [Qt.Key_Equal]: "Equal", [Qt.Key_BracketLeft]: "BracketLeft",
            [Qt.Key_BracketRight]: "BracketRight", [Qt.Key_Semicolon]: "Semicolon", [Qt.Key_Apostrophe]: "Apostrophe",
            [Qt.Key_QuoteLeft]: "Grave", [Qt.Key_Backslash]: "Backslash", [Qt.Key_Insert]: "Insert",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaNext]: "XF86AudioNext",
            [Qt.Key_MediaPrevious]: "XF86AudioPrev", [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp",
            [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
        }
        return map[k] ?? ""
    }

    function captured(e) {
        if ([Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Control, Qt.Key_Shift, Qt.Key_Alt, Qt.Key_AltGr].includes(e.key)) return
        const name = keyName(e)
        if (e.key === Qt.Key_Escape && e.modifiers === Qt.NoModifier) { capturing = ""; return }
        if (name === "") { host.showError("That key isn't supported here"); return }
        const mods = []
        if (e.modifiers & Qt.MetaModifier) mods.push("Mod")
        if (e.modifiers & Qt.ControlModifier) mods.push("Ctrl")
        if (e.modifiers & Qt.AltModifier) mods.push("Alt")
        if (e.modifiers & Qt.ShiftModifier) mods.push("Shift")
        const key = mods.concat([name]).join("+")
        const target = capturing
        capturing = ""
        if (target === "+") newKey = key
        else if (key !== target) keys(["remap", target, key], "Shortcut " + target + " → " + key)
    }

    Item {
        id: catcher
        Keys.onPressed: e => { page.captured(e); e.accepted = true }
    }
    onCapturingChanged: if (capturing !== "") catcher.forceActiveFocus(); else page.host.contentItem.forceActiveFocus()

    component KeyBadge: Rectangle {
        id: kb
        property string keyText
        property bool active: false
        property bool dim: false
        signal clicked()
        width: kbRow.width + 16
        height: 28
        radius: 8
        color: active ? Qt.alpha(Colors.primary, 0.25) : kbHover.hovered ? Qt.alpha(Colors.onSurface, 0.08) : Colors.surfaceContainerHighest
        border.width: 1
        border.color: active ? Colors.primary : Colors.outlineVariant
        opacity: dim ? 0.5 : 1
        HoverHandler { id: kbHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: kb.clicked() }
        Row {
            id: kbRow
            anchors.centerIn: parent
            height: parent.height
            spacing: 4
            Repeater {
                model: kb.active ? ["Press a shortcut…  (Esc cancels)"] : kb.keyText.split("+")
                Text {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData === "Mod" || modelData === "Super" ? "󰘳 Super" : modelData
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: kb.active ? Colors.primary : Colors.onSurface
                }
            }
        }
    }

    Column {
        id: toolbar
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8; rightMargin: 12 }
        spacing: 8
        Item {
            width: parent.width
            height: 34
            STextBox {
                anchors { left: parent.left; right: countText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                icon: "󰍉"
                placeholder: "Search shortcuts — key, action or command"
                commitOnBlur: false
                onEdited: v => page.query = v
            }
            SHint {
                id: countText
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                wrapMode: Text.NoWrap
                text: page.shown.length + " / " + page.binds.length
            }
        }
        SHint {
            width: parent.width
            leftPadding: 14
            text: "Click a key to change it. While it waits, niri's own shortcuts are paused so any combination reaches this window."
        }
    }

    SWheel { flick: flick }
    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: toolbar.bottom; topMargin: 6; bottom: parent.bottom }
        contentHeight: col.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}

        Column {
            id: col
            width: flick.width - 12
            spacing: 2

            SHeading { text: "ADD A SHORTCUT" }
            Item {
                width: parent.width
                height: 50
                Row {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    KeyBadge {
                        anchors.verticalCenter: parent.verticalCenter
                        keyText: page.newKey || "Choose key"
                        active: page.capturing === "+"
                        onClicked: page.capturing = "+"
                    }
                    SDropdown {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 190
                        options: ["spawn", "spawn-sh", "close-window", "toggle-overview", "fullscreen-window", "maximize-column",
                                  "toggle-window-floating", "center-column", "screenshot", "power-off-monitors", "quit"]
                        labels: ["Run program", "Run shell command", "Close window", "Overview", "Fullscreen", "Maximize column",
                                 "Toggle floating", "Center column", "Screenshot", "Screens off", "Quit niri"]
                        current: page.newAction
                        onPicked: v => page.newAction = v
                    }
                    STextBox {
                        visible: page.newAction === "spawn" || page.newAction === "spawn-sh"
                        anchors.verticalCenter: parent.verticalCenter
                        width: 220
                        placeholder: page.newAction === "spawn" ? "program args…" : "shell command"
                        commitOnBlur: false
                        onEdited: v => page.newArgs = v
                    }
                    SButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰐕"; text: "Add"
                        busy: page.newKey === "" || ((page.newAction === "spawn" || page.newAction === "spawn-sh") && page.newArgs.trim() === "")
                        onClicked: {
                            const args = page.newAction === "spawn" ? page.newArgs.trim().split(/\s+/)
                                : page.newAction === "spawn-sh" ? [page.newArgs.trim()] : []
                            page.keys(["add", page.newKey, page.newAction].concat(args), "Adding " + page.newKey)
                            page.newKey = ""
                        }
                    }
                }
            }

            Repeater {
                model: page.groups
                Column {
                    id: grp
                    required property var modelData
                    width: col.width
                    spacing: 0
                    SHeading { text: grp.modelData.title.toUpperCase() + "  ·  " + grp.modelData.items.length }
                    Repeater {
                        model: grp.modelData.items
                        Rectangle {
                            id: br
                            required property var modelData
                            width: grp.width
                            height: 44
                            radius: 10
                            color: brHover.hovered ? Qt.alpha(Colors.onSurface, 0.04) : "transparent"
                            HoverHandler { id: brHover }

                            KeyBadge {
                                id: badge
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                keyText: br.modelData.key
                                active: page.capturing === br.modelData.key
                                dim: !br.modelData.enabled
                                onClicked: page.capturing = br.modelData.key
                            }
                            SLabel {
                                anchors { left: parent.left; leftMargin: 290; right: brRight.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                text: page.describe(br.modelData)
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                color: br.modelData.enabled ? Colors.onSurface : Colors.outline
                            }
                            Row {
                                id: brRight
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                SButton {
                                    visible: br.modelData.added
                                    anchors.verticalCenter: parent.verticalCenter
                                    flat: true; danger: true
                                    icon: "󰆴"; text: ""
                                    onClicked: page.keys(["remove", br.modelData.key], "Removing " + br.modelData.key)
                                }
                                SToggle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: br.modelData.enabled
                                    onToggled: v => page.keys([v ? "enable" : "disable", br.modelData.key],
                                                              (v ? "Enabling " : "Disabling ") + br.modelData.key)
                                }
                            }
                        }
                    }
                }
            }
            SHint {
                visible: page.shown.length === 0 && page.binds.length > 0
                leftPadding: 14; topPadding: 12
                text: "No shortcut matches."
            }
        }
    }
}
