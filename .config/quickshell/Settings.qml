import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

// Okno nastavení ricu (Mod+S, `rp-shell settings toggle`). Je to obyčejné
// plovoucí okno (xdg toplevel), ne vrstva — dá se přesouvat, niri mu kreslí
// otevírací animaci a window-rule v config.kdl ho otevře plovoucí.
//
// Okno samo nic nepočítá ani nezapisuje: hodnoty, rozsahy i výchozí stavy
// dodává `rp-settings dump`, změny jdou přes `rp-settings set`, které je
// ověří (a niri část projde `niri validate`). Power stránka volá rp-power,
// Tools jen spouští hotové GUI nástroje.
//
// Změna tématu přepíše Colors.js a quickshell se celý znovu načte — otevřené
// okno a vybraná stránka proto přežívají v PersistentProperties.
FloatingWindow {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    title: "RPRice Settings"
    implicitWidth: 880
    implicitHeight: 620
    minimumSize: Qt.size(760, 520)
    visible: false
    color: "transparent"

    BackgroundEffect.blurRegion: Region { item: bg; radius: 16 }

    property var settings: ({})      // klíč → { value, default, min, max, options, changed }
    property var modules: []
    property string error: ""
    property string powerMode: "?"
    property string powerSource: ""
    property var tools: []
    property bool applyingTheme: false

    readonly property var pages: [
        { icon: "󰏘", label: "Appearance" },
        { icon: "󰍽", label: "Input" },
        { icon: "󰸌", label: "Theme" },
        { icon: "󰂄", label: "Power" },
        { icon: "󰒓", label: "Tools" },
    ]

    PersistentProperties {
        id: persist
        reloadableId: "rpSettings"
        property bool open: false
        property int page: 0
    }

    Component.onCompleted: if (persist.open) open()
    onVisibleChanged: {
        persist.open = visible
        if (visible) reload()
    }

    function open() {
        visible = true
    }

    function toggle() {
        if (visible) visible = false
        else open()
    }

    // `rp-shell settings theme` apod. — otevřít rovnou na stránce (podle názvu)
    function openPage(name) {
        const i = pages.findIndex(p => p.label.toLowerCase() === name)
        if (i < 0) return false
        persist.page = i
        open()
        return true
    }

    function reload() {
        dumpProc.running = false
        dumpProc.running = true
        powerProc.running = false
        powerProc.running = true
        toolsProc.running = false
        toolsProc.running = true
    }

    function val(key) {
        return settings[key] ? settings[key].value : undefined
    }

    // Hned překreslit (optimisticky), zapsat na pozadí; chyba vrátí stav z dumpu
    function set(key, value) {
        const s = settings[key]
        if (!s || s.value === value) return
        const copy = Object.assign({}, settings)
        copy[key] = Object.assign({}, s, { value: value, changed: value !== s.default })
        settings = copy
        run(["rp-settings", "set", key, String(value)])
    }

    function setModule(name, on) {
        modules = modules.map(m => m.name === name ? Object.assign({}, m, { enabled: on }) : m)
        run(["rp-settings", "module", name, on ? "on" : "off"])
    }

    // ---------------------------------------------------------- procesy

    // Příkazy za sebou, ať se dva zápisy settings.json nepřebíjejí
    property var queue: []

    function run(cmd) {
        queue = queue.concat([cmd])
        if (!runner.running) next()
    }

    function next() {
        if (queue.length === 0) return
        const cmd = queue[0]
        queue = queue.slice(1)
        runner.command = ["bash", "-c",
            'cmd="$HOME/.local/bin/$1"; shift; out=$("$cmd" "$@" 2>&1) || printf "ERR %s" "$out"',
            "_"].concat(cmd)
        runner.running = true
    }

    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.startsWith("ERR ")) {
                    root.error = text.slice(4).trim().replace(/^rp-settings: /, "")
                    errorTimer.restart()
                    dumpProc.running = true
                }
            }
        }
        // Po poslední změně si stáhnout skutečný stav (rp-settings hodnoty normalizuje)
        onExited: {
            if (root.queue.length === 0) dumpProc.running = true
            root.next()
        }
    }

    Timer { id: errorTimer; interval: 6000; onTriggered: root.error = "" }

    Process {
        id: dumpProc
        command: [root.bin + "rp-settings", "dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const m = {}
                    for (const s of d.settings) m[s.key] = s
                    root.settings = m
                    root.modules = d.modules
                } catch (e) {
                    root.error = "rp-settings dump failed"
                }
            }
        }
    }

    Process {
        id: powerProc
        command: ["bash", "-c", "$HOME/.local/bin/rp-power status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const field = key => {
                    const line = text.split("\n").find(l => l.startsWith(key))
                    return line ? line.slice(key.length).replace(":", "").trim() : ""
                }
                root.powerMode = field("režim") || "?"
                const src = field("napájení")
                root.powerSource = src === "síť" ? "AC" : src === "baterie" ? "Battery" : src
            }
        }
    }

    Process {
        id: powerSet
        onExited: powerProc.running = true
    }

    function setPower(mode) {
        powerMode = mode
        powerSet.command = ["bash", "-c", "$HOME/.local/bin/rp-power " + mode]
        powerSet.running = true
    }

    readonly property var toolList: [
        { cmd: "pavucontrol",          icon: "󰕾", label: "Volume control",   hint: "pavucontrol" },
        { cmd: "blueman-manager",      icon: "󰂯", label: "Bluetooth",        hint: "blueman" },
        { cmd: "nm-connection-editor", icon: "󰛳", label: "Network connections", hint: "nm-connection-editor" },
        { cmd: "wdisplays",            icon: "󰍹", label: "Displays",         hint: "wdisplays (kanshi keeps profiles)" },
        { cmd: "nwg-look",             icon: "󰉼", label: "GTK appearance",   hint: "nwg-look — icons, cursor, fonts" },
        { cmd: "qt6ct",                icon: "󰙯", label: "Qt appearance",    hint: "qt6ct" },
        { cmd: "btop",                 icon: "󰍛", label: "System monitor",   hint: "btop in kitty", term: true },
    ]

    // Jen nástroje, které jsou nainstalované
    Process {
        id: toolsProc
        command: ["bash", "-c", "for c in " + root.toolList.map(t => t.cmd).join(" ")
            + "; do command -v \"$c\" >/dev/null && echo \"$c\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const have = text.split("\n")
                root.tools = root.toolList.filter(t => have.includes(t.cmd))
            }
        }
    }

    Process {
        id: themeProc
        command: ["bash", "-c", "$HOME/.local/bin/apply-wallpaper-theme.sh"]
        onExited: root.applyingTheme = false
    }

    function applyTheme() {
        if (themeProc.running) return
        applyingTheme = true
        themeProc.running = true
    }

    // ------------------------------------------------------------- ovládací prvky

    component Label: Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        color: Colors.onSurface
    }

    component Hint: Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: Colors.onSurfaceVariant
        wrapMode: Text.WordWrap
    }

    component Heading: Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        color: Colors.primary
        topPadding: 18
        bottomPadding: 6
    }

    // Řádek: popis vlevo, ovládací prvek vpravo
    component SettingRow: Item {
        id: row
        property string label
        property string hint
        property bool changed: false
        default property alias control: slot.data

        width: parent ? parent.width : 0
        height: Math.max(56, texts.implicitHeight + 24)

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: hover.hovered ? Qt.alpha(Colors.onSurface, 0.04) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        HoverHandler { id: hover }

        Column {
            id: texts
            anchors {
                left: parent.left; leftMargin: 14
                right: slot.left; rightMargin: 20
                verticalCenter: parent.verticalCenter
            }
            spacing: 3
            Row {
                spacing: 8
                Label { text: row.label }
                // Tečka = hodnota se liší od výchozí
                Rectangle {
                    visible: row.changed
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: Colors.tertiary
                }
            }
            Hint { visible: row.hint !== ""; text: row.hint; width: parent.width }
        }

        Item {
            id: slot
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    component Toggle: Rectangle {
        id: tg
        property bool checked
        signal toggled(bool value)

        width: 46; height: 26; radius: 13
        color: checked ? Colors.primary : Colors.surfaceContainerHighest
        border.width: 1
        border.color: checked ? Colors.primary : Colors.outlineVariant
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width: 20; height: 20; radius: 10
            anchors.verticalCenter: parent.verticalCenter
            x: tg.checked ? tg.width - width - 3 : 3
            color: tg.checked ? Colors.onPrimary : Colors.outline
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tg.toggled(!tg.checked)
        }
    }

    // Posuvník; zapisuje až po puštění, ať se niri config nepřepisuje při tažení
    component Slider: Item {
        id: sl
        property real from: 0
        property real to: 1
        property real value: 0
        property real step: 1
        property int decimals: 0
        property string suffix: ""
        property real live: value
        property bool dragging: false
        signal moved(real value)

        width: 260; height: 26
        onValueChanged: if (!dragging) live = value

        function at(x) {
            const f = Math.max(0, Math.min(1, x / track.width))
            const v = Math.round((from + (to - from) * f) / step) * step
            return Number(v.toFixed(decimals))
        }

        Item {
            id: track
            width: parent.width - 54
            height: parent.height
            readonly property real frac: (sl.live - sl.from) / Math.max(sl.to - sl.from, 1e-9)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: Colors.surfaceContainerHighest
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * track.frac; height: 4; radius: 2
                color: Colors.primary
            }
            Rectangle {
                width: 18; height: 18; radius: 9
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * track.frac - width / 2
                color: Colors.primary
                border.width: 3
                border.color: Colors.surfaceContainer
                scale: sl.dragging ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => { sl.dragging = true; sl.live = sl.at(mouse.x - 6) }
                onPositionChanged: mouse => { if (pressed) sl.live = sl.at(mouse.x - 6) }
                onReleased: { sl.dragging = false; sl.moved(sl.live) }
            }
            WheelHandler {
                onWheel: event => sl.moved(Math.max(sl.from, Math.min(sl.to,
                    Number((sl.value + (event.angleDelta.y > 0 ? sl.step : -sl.step)).toFixed(sl.decimals)))))
            }
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 46
            horizontalAlignment: Text.AlignRight
            text: sl.live.toFixed(sl.decimals) + sl.suffix
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: Colors.onSurfaceVariant
        }
    }

    component Segmented: Rectangle {
        id: seg
        property var options: []
        property var labels: []
        property string current
        signal picked(string value)

        width: segRow.width + 6
        height: 32
        radius: 10
        color: Colors.surfaceContainerHighest

        Row {
            id: segRow
            x: 3; y: 3
            spacing: 2
            Repeater {
                model: seg.options
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: String(modelData) === seg.current
                    width: Math.max(64, segText.implicitWidth + 22)
                    height: 26
                    radius: 8
                    color: sel ? Colors.primary : segHover.hovered ? Qt.alpha(Colors.onSurface, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { id: segHover }
                    Text {
                        id: segText
                        anchors.centerIn: parent
                        text: seg.labels[index] ?? String(modelData)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: sel ? Colors.onPrimary : Colors.onSurfaceVariant
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(String(modelData))
                    }
                }
            }
        }
    }

    component Button: Rectangle {
        id: btn
        property string text
        property string icon: ""
        property bool busy: false
        signal clicked()

        width: btnRow.width + 28
        height: 34
        radius: 10
        color: btnHover.hovered ? Qt.alpha(Colors.primary, 0.22) : Qt.alpha(Colors.primary, 0.12)
        border.width: 1
        border.color: Qt.alpha(Colors.primary, 0.45)
        opacity: busy ? 0.6 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        HoverHandler { id: btnHover }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: btn.icon !== ""
                text: btn.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: Colors.primary
            }
            Text {
                text: btn.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Colors.onSurface
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!btn.busy) btn.clicked()
        }
    }

    // Stránka: posuvný sloupec s obsahem
    component Page: Flickable {
        id: pg
        default property alias content: pageCol.data
        contentHeight: pageCol.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: pageCol
            width: pg.width
            spacing: 2
        }
    }

    // ------------------------------------------------------------------ okno

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Qt.alpha(Colors.surface, 0.86)
        focus: true
        Keys.onEscapePressed: root.visible = false
        Keys.onPressed: event => {
            // Ctrl+Tab / Ctrl+Shift+Tab listují stránky
            if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) {
                persist.page = (persist.page + 1) % root.pages.length
                event.accepted = true
            } else if (event.key === Qt.Key_Backtab) {
                persist.page = (persist.page - 1 + root.pages.length) % root.pages.length
                event.accepted = true
            }
        }

        // ── Postranní panel
        Rectangle {
            id: sidebar
            width: 220
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            color: Qt.alpha(Colors.surfaceContainer, 0.7)

            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: 1
                color: Qt.alpha(Colors.outlineVariant, 0.6)
            }

            Column {
                anchors { fill: parent; margins: 14; topMargin: 22 }
                spacing: 4

                Text {
                    text: "Settings"
                    leftPadding: 10
                    bottomPadding: 16
                    font.family: root.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: Colors.onSurface
                }

                Repeater {
                    model: root.pages
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool sel: persist.page === index
                        width: parent.width
                        height: 40
                        radius: 10
                        color: sel ? Qt.alpha(Colors.primary, 0.18)
                            : navHover.hovered ? Qt.alpha(Colors.onSurface, 0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        HoverHandler { id: navHover }

                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Text {
                                text: modelData.icon
                                font.family: root.fontFamily
                                font.pixelSize: 16
                                color: sel ? Colors.primary : Colors.onSurfaceVariant
                            }
                            Text {
                                text: modelData.label
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: sel ? Font.Medium : Font.Normal
                                color: sel ? Colors.onSurface : Colors.onSurfaceVariant
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: persist.page = index
                        }
                    }
                }
            }

            Text {
                anchors { left: parent.left; bottom: parent.bottom; margins: 24 }
                text: "Esc to close"
                font.family: root.fontFamily
                font.pixelSize: 10
                color: Colors.outline
            }
        }

        // ── Obsah
        Item {
            id: contentArea
            anchors {
                top: parent.top; bottom: parent.bottom
                left: sidebar.right; right: parent.right
                leftMargin: 28; rightMargin: 28; topMargin: 22
            }

            Text {
                id: pageTitle
                text: root.pages[persist.page].label
                font.family: root.fontFamily
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: Colors.onSurface
            }

            Item {
                id: pagesBox
                anchors { top: pageTitle.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }

                // ── Appearance
                Page {
                    anchors.fill: parent
                    visible: persist.page === 0

                    Heading { text: "LAYOUT" }
                    SettingRow {
                        label: "Gaps"
                        hint: "Space between windows and around the screen edge."
                        changed: root.settings["niri.gaps"]?.changed ?? false
                        Slider {
                            from: root.settings["niri.gaps"]?.min ?? 0
                            to: root.settings["niri.gaps"]?.max ?? 48
                            value: root.val("niri.gaps") ?? 16
                            suffix: " px"
                            onMoved: v => root.set("niri.gaps", v)
                        }
                    }
                    SettingRow {
                        label: "New column width"
                        hint: "Default width of newly opened windows."
                        changed: root.settings["niri.default_width"]?.changed ?? false
                        Segmented {
                            options: root.settings["niri.default_width"]?.options ?? []
                            labels: ["1/3", "1/2", "2/3"]
                            current: root.val("niri.default_width") ?? ""
                            onPicked: v => root.set("niri.default_width", v)
                        }
                    }
                    SettingRow {
                        label: "Center focused column"
                        hint: "Keep the focused column in the middle of the screen."
                        changed: root.settings["niri.center_column"]?.changed ?? false
                        Segmented {
                            options: root.settings["niri.center_column"]?.options ?? []
                            labels: ["Never", "Always", "On overflow"]
                            current: root.val("niri.center_column") ?? ""
                            onPicked: v => root.set("niri.center_column", v)
                        }
                    }

                    Heading { text: "WINDOWS" }
                    SettingRow {
                        label: "Focus ring width"
                        hint: "0 turns the ring off. Colors come from the wallpaper."
                        changed: root.settings["niri.focus_ring_width"]?.changed ?? false
                        Slider {
                            from: root.settings["niri.focus_ring_width"]?.min ?? 0
                            to: root.settings["niri.focus_ring_width"]?.max ?? 12
                            value: root.val("niri.focus_ring_width") ?? 4
                            suffix: " px"
                            onMoved: v => root.set("niri.focus_ring_width", v)
                        }
                    }
                    SettingRow {
                        label: "Corner radius"
                        hint: "Rounds and clips every window. 0 leaves corners to the apps."
                        changed: root.settings["niri.corner_radius"]?.changed ?? false
                        Slider {
                            from: root.settings["niri.corner_radius"]?.min ?? 0
                            to: root.settings["niri.corner_radius"]?.max ?? 24
                            value: root.val("niri.corner_radius") ?? 0
                            suffix: " px"
                            onMoved: v => root.set("niri.corner_radius", v)
                        }
                    }
                    SettingRow {
                        label: "Window shadows"
                        changed: root.settings["niri.shadow"]?.changed ?? false
                        Toggle {
                            checked: root.val("niri.shadow") ?? true
                            onToggled: v => root.set("niri.shadow", v)
                        }
                    }
                }

                // ── Input
                Page {
                    anchors.fill: parent
                    visible: persist.page === 1

                    Heading { text: "FOCUS" }
                    SettingRow {
                        label: "Focus follows mouse"
                        hint: "Hovering a window focuses it, without scrolling the view."
                        changed: root.settings["input.focus_follows_mouse"]?.changed ?? false
                        Toggle {
                            checked: root.val("input.focus_follows_mouse") ?? true
                            onToggled: v => root.set("input.focus_follows_mouse", v)
                        }
                    }

                    Heading { text: "TOUCHPAD" }
                    SettingRow {
                        label: "Tap to click"
                        changed: root.settings["input.touchpad_tap"]?.changed ?? false
                        Toggle {
                            checked: root.val("input.touchpad_tap") ?? true
                            onToggled: v => root.set("input.touchpad_tap", v)
                        }
                    }
                    SettingRow {
                        label: "Natural scrolling"
                        hint: "Content moves with your fingers."
                        changed: root.settings["input.natural_scroll"]?.changed ?? false
                        Toggle {
                            checked: root.val("input.natural_scroll") ?? true
                            onToggled: v => root.set("input.natural_scroll", v)
                        }
                    }

                    Heading { text: "MOUSE" }
                    SettingRow {
                        label: "Pointer speed"
                        hint: "Acceleration, −1 slowest to 1 fastest."
                        changed: root.settings["input.mouse_accel"]?.changed ?? false
                        Slider {
                            from: -1; to: 1; step: 0.05; decimals: 2
                            value: root.val("input.mouse_accel") ?? 0
                            onMoved: v => root.set("input.mouse_accel", v)
                        }
                    }
                }

                // ── Theme
                Page {
                    anchors.fill: parent
                    visible: persist.page === 2

                    Heading { text: "COLORS" }
                    SettingRow {
                        label: "Wallpaper"
                        hint: "Pick a wallpaper; the whole theme follows it."
                        Button {
                            icon: "󰸉"; text: "Choose…"
                            onClicked: Quickshell.execDetached([root.bin + "rp-shell", "wallpaper", "open"])
                        }
                    }
                    SettingRow {
                        label: "Monochrome scheme"
                        hint: "Grey palette for black-and-white wallpapers. Auto detects them."
                        changed: root.settings["theme.mono_mode"]?.changed ?? false
                        Segmented {
                            options: root.settings["theme.mono_mode"]?.options ?? []
                            labels: ["Auto", "On", "Off"]
                            current: root.val("theme.mono_mode") ?? ""
                            onPicked: v => root.set("theme.mono_mode", v)
                        }
                    }
                    SettingRow {
                        label: "Regenerate theme"
                        hint: "Re-run matugen and every enabled module on the current wallpaper."
                        Button {
                            icon: root.applyingTheme ? "󰔟" : "󰑓"
                            text: root.applyingTheme ? "Applying…" : "Apply now"
                            busy: root.applyingTheme
                            onClicked: root.applyTheme()
                        }
                    }

                    Heading { text: "THEMED APPS" }
                    Hint {
                        width: parent.width
                        leftPadding: 14; rightPadding: 14; bottomPadding: 6
                        text: "Modules that repaint an app after each wallpaper change (modules.conf)."
                    }
                    Repeater {
                        model: root.modules.filter(m => !/cache-hygiene|smoke-test|postprocess/.test(m.name))
                        SettingRow {
                            required property var modelData
                            label: modelData.name.replace(/^\d+-/, "").replace(/\.sh$/, "")
                            hint: modelData.requires !== "" ? "needs " + modelData.requires : ""
                            height: 46
                            Toggle {
                                checked: modelData.enabled
                                onToggled: v => root.setModule(modelData.name, v)
                            }
                        }
                    }
                }

                // ── Power
                Page {
                    anchors.fill: parent
                    visible: persist.page === 3

                    Heading { text: "MODE" }
                    Hint {
                        width: parent.width
                        leftPadding: 14; rightPadding: 14; bottomPadding: 8
                        text: "Power source: " + (root.powerSource || "?")
                            + ". Unplugging always drops to Battery; plugging back in restores your choice."
                    }
                    Repeater {
                        model: [
                            { id: "battery",  icon: "󰁹", label: "Battery",  hint: "CPU powersave, dGPU capped at 40 W, video wallpaper suspended" },
                            { id: "balanced", icon: "󰗑", label: "Balanced", hint: "Everyday default" },
                            { id: "gaming",   icon: "󰊴", label: "Gaming",   hint: "Full power, dGPU clock floor, video wallpaper suspended" },
                        ]
                        SettingRow {
                            required property var modelData
                            label: modelData.icon + "  " + modelData.label
                            hint: modelData.hint
                            Toggle {
                                checked: root.powerMode === modelData.id
                                onToggled: root.setPower(modelData.id)
                            }
                        }
                    }
                }

                // ── Tools
                Page {
                    anchors.fill: parent
                    visible: persist.page === 4

                    Heading { text: "SYSTEM TOOLS" }
                    Repeater {
                        model: root.tools
                        SettingRow {
                            required property var modelData
                            label: modelData.icon + "  " + modelData.label
                            hint: modelData.hint
                            Button {
                                icon: "󰏌"; text: "Open"
                                onClicked: Quickshell.execDetached(modelData.term
                                    ? ["kitty", "-e", modelData.cmd] : [modelData.cmd])
                            }
                        }
                    }

                    Heading { text: "CONFIG FILES" }
                    SettingRow {
                        label: "Reset to defaults"
                        hint: "Forget everything set in this window (settings.json)."
                        Button {
                            icon: "󰦛"; text: "Reset"
                            onClicked: root.run(["rp-settings", "reset"])
                        }
                    }
                    SettingRow {
                        label: "Open dotfiles"
                        hint: "~/dotfiles in yazi"
                        Button {
                            icon: "󰉋"; text: "Open"
                            onClicked: Quickshell.execDetached(["kitty", "--directory", Quickshell.env("HOME") + "/dotfiles", "yazi"])
                        }
                    }
                }
            }
        }

        // ── Chybová hláška (např. neplatný niri config po zápisu)
        Rectangle {
            visible: root.error !== ""
            anchors { bottom: parent.bottom; horizontalCenter: contentArea.horizontalCenter; bottomMargin: 18 }
            width: Math.min(contentArea.width, errText.implicitWidth + 32)
            height: errText.implicitHeight + 18
            radius: 10
            color: Qt.alpha(Colors.errorColor, 0.18)
            border.width: 1
            border.color: Qt.alpha(Colors.errorColor, 0.6)
            Text {
                id: errText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, contentArea.width - 32)
                text: root.error
                wrapMode: Text.WordWrap
                font.family: root.fontFamily
                font.pixelSize: 12
                color: Colors.onSurface
            }
        }
    }
}
