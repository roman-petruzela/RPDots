import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "Colors.js" as Colors

// Okno nastavení ricu (Mod+S, `rp-shell settings toggle`, v launcheru jako
// „Settings“). Je to obyčejné plovoucí okno (xdg toplevel), ne vrstva — dá se
// přesouvat, niri mu kreslí otevírací animaci a window-rule v config.kdl ho
// otevře plovoucí. `rp-shell settings <stránka>` ho otevře rovnou na stránce
// (appearance, windows, keyboard, mouse, theme, notifications, power, tools).
//
// Okno samo nic nepočítá ani nezapisuje: typy, rozsahy, volby i výchozí stavy
// dodává `rp-settings dump`, změny jdou přes `rp-settings set`, které je ověří
// a aplikuje (niri část projde `niri validate`). Tady je jen rozložení:
// `pages` popisuje, který klíč patří na kterou stránku a jak se jmenuje;
// ovládací prvek se vybere podle typu (bool → přepínač, číslo → posuvník,
// enum → segmenty nebo rozbalovací seznam, string → textové pole). Nová volba
// = klíč ve schématu rp-settings + jeden řádek tady.
//
// Změna tématu přepíše Colors.js a quickshell se celý znovu načte — otevřené
// okno a vybraná stránka proto přežívají v PersistentProperties.
//
// Okno se při každém otevření vytváří znovu (LazyLoader) a při zavření zahazuje.
// Když ho zavře niri (Mod+Q), quickshell zničí jeho toplevel, ale objekt zůstane
// s visible: true — `visible = true` pak už nic neotevře.
Scope {
    id: outer
    reloadableId: "rpSettingsScope"

    // Řádek: { key, label, hint, labels (pro enum), suffix, step, decimals,
    //          percent (0–1 jako %), zero (popisek pro 0, např. "Off") }
    // nebo zvláštní druh: { kind: "button" | "modules" | "power" | "tools" | "note" }
    readonly property var pages: [
        { id: "appearance", icon: "󰏘", label: "Appearance", sections: [
            { title: "WINDOWS", rows: [
                { key: "niri.gaps", label: "Gaps", hint: "Space between windows and around the screen edge.", suffix: " px" },
                { key: "niri.corner_radius", label: "Corner radius", hint: "Rounds and clips every window.", suffix: " px", zero: "Off" },
                { key: "niri.focus_ring_width", label: "Focus ring", hint: "Outline of the focused window. Colors follow the wallpaper.", suffix: " px", zero: "Off" },
                { key: "niri.inactive_opacity", label: "Inactive window opacity", hint: "Fade windows that don't have focus.", percent: true, step: 0.05 },
            ]},
            { title: "SHADOWS", rows: [
                { key: "niri.shadow", label: "Window shadows" },
                { key: "niri.shadow_softness", label: "Softness", hint: "Blur radius of the shadow.", suffix: " px" },
                { key: "niri.shadow_spread", label: "Spread", hint: "How far the shadow reaches past the window.", suffix: " px" },
            ]},
            { title: "BLUR", rows: [
                { key: "niri.blur_passes", label: "Passes", hint: "More passes = stronger blur, more GPU work." },
                { key: "niri.blur_offset", label: "Radius", hint: "Sample distance per pass.", step: 0.5, decimals: 1 },
                { key: "niri.blur_noise", label: "Noise", hint: "Grain on top of the blur, hides banding.", step: 0.01 },
                { key: "niri.blur_saturation", label: "Saturation", hint: "Color boost of whatever is behind.", step: 0.05, suffix: "×" },
            ]},
            { title: "ANIMATIONS", rows: [
                { key: "niri.animations", label: "Animations", hint: "Window, workspace and overview animations." },
                { key: "niri.anim_slowdown", label: "Animation duration", hint: "1× is niri's default speed, higher is slower.", step: 0.05, suffix: "×" },
            ]},
        ]},
        { id: "windows", icon: "󰕰", label: "Windows", sections: [
            { title: "LAYOUT", rows: [
                { key: "niri.default_width", label: "New column width", hint: "Width of newly opened windows.", labels: ["1/3", "1/2", "2/3", "Full"] },
                { key: "niri.default_display", label: "New column display", hint: "Tabbed columns stack windows as tabs.", labels: ["Columns", "Tabs"] },
                { key: "niri.center_column", label: "Center focused column", labels: ["Never", "Always", "On overflow"] },
                { key: "niri.center_single", label: "Center a lone window", hint: "A single column on a workspace sits in the middle." },
                { key: "niri.empty_ws_first", label: "Empty workspace on top", hint: "Keep an empty workspace above the first one too." },
            ]},
            { title: "OVERVIEW", rows: [
                { key: "niri.overview_zoom", label: "Overview zoom", hint: "Size of workspaces in the overview (Mod+O).", percent: true, step: 0.05 },
                { key: "niri.hot_corner", label: "Hot corner", hint: "Push the pointer into this corner to open the overview.",
                  labels: ["Off", "Top left", "Top right", "Bottom left", "Bottom right"] },
            ]},
            { title: "FOCUS", rows: [
                { key: "input.focus_follows_mouse", label: "Focus follows mouse", hint: "Hovering a window focuses it, without scrolling the view." },
                { key: "input.warp_mouse", label: "Pointer follows focus", hint: "Move the pointer to windows focused from the keyboard." },
                { key: "input.ws_back_forth", label: "Workspace back and forth", hint: "Switching to the current workspace jumps to the previous one." },
            ]},
        ]},
        { id: "keyboard", icon: "󰌌", label: "Keyboard", sections: [
            { title: "LAYOUT", rows: [
                { key: "input.kb_layouts", label: "Layouts", hint: "Comma-separated XKB codes, e.g. cz,us or us,de." },
                { key: "input.kb_switch", label: "Switch layout with", hint: "Mod+Space always switches too.",
                  labels: ["Alt+Shift", "Ctrl+Shift", "Caps Lock", "Nothing"] },
                { key: "input.track_layout", label: "Remember layout", labels: ["Globally", "Per window"] },
                { key: "input.caps_lock", label: "Caps Lock key", labels: ["Caps Lock", "Escape", "Ctrl", "Swap with Esc", "Disabled"] },
                { key: "input.compose", label: "Compose key", hint: "Type special characters in sequences.", labels: ["None", "Right Alt", "Right Ctrl", "Menu"] },
            ]},
            { title: "TYPING", rows: [
                { key: "input.repeat_delay", label: "Repeat delay", hint: "How long to hold a key before it repeats.", suffix: " ms", step: 25 },
                { key: "input.repeat_rate", label: "Repeat rate", hint: "Characters per second while held.", suffix: "/s" },
                { key: "input.numlock", label: "Num Lock on at start" },
            ]},
        ]},
        { id: "mouse", icon: "󰍽", label: "Mouse & touchpad", sections: [
            { title: "TOUCHPAD", rows: [
                { key: "input.touchpad_tap", label: "Tap to click" },
                { key: "input.touchpad_drag", label: "Tap and drag", hint: "Double-tap and hold to drag." },
                { key: "input.touchpad_drag_lock", label: "Drag lock", hint: "Briefly lifting the finger doesn't drop what you drag." },
                { key: "input.touchpad_dwt", label: "Disable while typing" },
                { key: "input.touchpad_external_off", label: "Disable with a mouse plugged in" },
                { key: "input.natural_scroll", label: "Natural scrolling", hint: "Content moves with your fingers." },
                { key: "input.touchpad_accel", label: "Pointer speed", hint: "−1 slowest, 1 fastest.", step: 0.05 },
                { key: "input.touchpad_profile", label: "Acceleration", labels: ["Adaptive", "Flat"] },
                { key: "input.touchpad_scroll", label: "Scroll speed", step: 0.05, suffix: "×" },
                { key: "input.touchpad_click", label: "Click method", hint: "Clickfinger: 2 fingers = right, 3 = middle.",
                  labels: ["Default", "Areas", "Fingers"] },
                { key: "input.touchpad_tap_map", label: "Two/three-finger tap", labels: ["Right / middle", "Middle / right"] },
            ]},
            { title: "MOUSE", rows: [
                { key: "input.mouse_accel", label: "Pointer speed", hint: "−1 slowest, 1 fastest.", step: 0.05 },
                { key: "input.mouse_profile", label: "Acceleration", hint: "Flat is usual for games.", labels: ["Adaptive", "Flat"] },
                { key: "input.mouse_natural", label: "Natural scrolling" },
                { key: "input.mouse_scroll", label: "Scroll speed", step: 0.05, suffix: "×" },
                { key: "input.mouse_left_handed", label: "Left-handed", hint: "Swap left and right buttons." },
            ]},
            { title: "CURSOR", rows: [
                { key: "cursor.theme", label: "Cursor theme", hint: "Applied to niri, GTK and X11 apps; running apps may need a restart." },
                { key: "cursor.size", label: "Cursor size", suffix: " px", step: 2 },
                { key: "cursor.hide_typing", label: "Hide while typing", hint: "Can confuse mouselook in some Wine games." },
                { key: "cursor.hide_after", label: "Hide when idle", hint: "Hide the pointer after this long without movement.", suffix: " s", zero: "Never" },
            ]},
        ]},
        { id: "theme", icon: "󰸌", label: "Theme", sections: [
            { title: "COLORS", rows: [
                { kind: "button", action: "wallpaper", label: "Wallpaper", hint: "Pick a wallpaper; the whole theme follows it.", icon: "󰸉", text: "Choose…" },
                { key: "theme.scheme", label: "Color scheme", hint: "How matugen derives the palette from the wallpaper.",
                  labels: ["Tonal spot", "Content", "Expressive", "Fidelity", "Fruit salad", "Rainbow", "Neutral"] },
                { key: "theme.contrast", label: "Contrast", hint: "−1 softest, 0 standard, 1 strongest.", step: 0.1, decimals: 1 },
                { key: "theme.mono_mode", label: "Monochrome scheme", hint: "Grey palette for black-and-white wallpapers.", labels: ["Auto", "On", "Off"] },
                { kind: "button", action: "theme", label: "Regenerate theme", hint: "Scheme, contrast and monochrome apply on the next regenerate.", icon: "󰑓", text: "Apply now" },
            ]},
            { title: "WALLPAPER", rows: [
                { key: "wallpaper.transition", label: "Transition", hint: "Animation when the wallpaper changes.",
                  labels: ["None", "Simple", "Fade", "Wipe", "Wave", "Grow", "Center", "Outer", "Left", "Right", "Top", "Bottom", "Any", "Random"] },
                { key: "wallpaper.transition_step", label: "Transition speed", hint: "Higher is faster." },
            ]},
            { title: "TERMINAL & APPS", rows: [
                { key: "theme.terminal_opacity", label: "Terminal opacity", hint: "kitty background; running terminals update live.", percent: true, step: 0.05 },
                { key: "theme.terminal_font", label: "Terminal font size", suffix: " pt", step: 0.5, decimals: 1 },
                { key: "theme.spotify_opacity", label: "Spotify opacity", hint: "Spotify can't do real transparency, so text fades too.", percent: true, step: 0.05 },
            ]},
            { title: "THEMED APPS", rows: [
                { kind: "note", text: "Modules that repaint an app after each wallpaper change (modules.conf)." },
                { kind: "modules" },
            ]},
        ]},
        { id: "notifications", icon: "󰂚", label: "Notifications & idle", sections: [
            { title: "NOTIFICATIONS", rows: [
                { key: "notify.dnd", label: "Do not disturb", hint: "Hide notifications until turned off." },
                { key: "notify.position", label: "Position",
                  labels: ["Top left", "Top center", "Top right", "Bottom left", "Bottom center", "Bottom right"] },
                { key: "notify.timeout", label: "Dismiss after", hint: "Urgent ones stay until clicked.", suffix: " s", zero: "Never" },
                { key: "notify.max_visible", label: "Visible at once" },
                { kind: "button", action: "test-notify", label: "Test", hint: "Send a sample notification.", icon: "󰂚", text: "Send" },
            ]},
            { title: "IDLE", rows: [
                { key: "idle.lock_min", label: "Lock screen after", suffix: " min", zero: "Never" },
                { key: "idle.screen_off_min", label: "Turn screens off after", suffix: " min", zero: "Never" },
                { key: "idle.lock_on_sleep", label: "Lock before sleep" },
                { kind: "button", action: "lock", label: "Lock now", icon: "󰌾", text: "Lock" },
            ]},
        ]},
        { id: "power", icon: "󰂄", label: "Power", sections: [
            { title: "MODE", rows: [ { kind: "power" } ]},
        ]},
        { id: "tools", icon: "󰒓", label: "Tools", sections: [
            { title: "SYSTEM TOOLS", rows: [ { kind: "tools" } ]},
            { title: "MAINTENANCE", rows: [
                { kind: "button", action: "reset", label: "Reset everything", hint: "Forget everything set in this window (settings.json).", icon: "󰦛", text: "Reset" },
                { kind: "button", action: "dotfiles", label: "Open dotfiles", hint: "~/dotfiles in yazi", icon: "󰉋", text: "Open" },
            ]},
        ]},
    ]

    PersistentProperties {
        id: persist
        reloadableId: "rpSettings"
        property bool open: false
        property int page: 0
    }

    function open()   { persist.open = true }
    function hide()   { persist.open = false }
    function toggle() { persist.open = !persist.open }

    // `rp-shell settings theme` apod. — otevřít rovnou na stránce
    function openPage(name) {
        const i = pages.findIndex(p => p.id === name || p.label.toLowerCase() === name)
        if (i < 0) return false
        persist.page = i
        open()
        return true
    }

    LazyLoader {
        active: persist.open

        FloatingWindow {
            id: root

            readonly property string fontFamily: "JetBrainsMono Nerd Font"
            readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

            title: "RPRice Settings"
            implicitWidth: 940
            implicitHeight: 680
            minimumSize: Qt.size(800, 520)
            visible: true
            color: "transparent"
            onClosed: outer.hide()

            BackgroundEffect.blurRegion: Region { item: bg; radius: 16 }

            property var settings: ({})      // klíč → { value, default, min, max, options, changed }
            property var modules: []
            property string error: ""
            property string powerMode: "?"
            property string powerSource: ""
            property var tools: []
            property bool applyingTheme: false
            property string query: ""

            readonly property var pages: outer.pages

            // Hledání: všechny řádky s klíčem nebo tlačítkem, které sedí na popis
            readonly property var results: {
                const q = query.trim().toLowerCase()
                if (q === "") return []
                const out = []
                for (const p of pages)
                    for (const s of p.sections)
                        for (const r of s.rows) {
                            if (!r.key && r.kind !== "button") continue
                            const hay = [r.label, r.hint, r.key, p.label, s.title].join(" ").toLowerCase()
                            if (q.split(/\s+/).every(w => hay.includes(w)))
                                out.push(Object.assign({}, r, { where: p.label }))
                        }
                return out
            }

            Component.onCompleted: reload()

            function reload() {
                dumpProc.running = false
                dumpProc.running = true
                powerProc.running = false
                powerProc.running = true
                toolsProc.running = false
                toolsProc.running = true
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

            function reset(key) {
                const s = settings[key]
                if (!s) return
                const copy = Object.assign({}, settings)
                copy[key] = Object.assign({}, s, { value: s.default, changed: false })
                settings = copy
                run(["rp-settings", "reset", key])
            }

            function setModule(name, on) {
                modules = modules.map(m => m.name === name ? Object.assign({}, m, { enabled: on }) : m)
                run(["rp-settings", "module", name, on ? "on" : "off"])
            }

            function action(name) {
                if (name === "wallpaper") Quickshell.execDetached([bin + "rp-shell", "wallpaper", "open"])
                else if (name === "theme") applyTheme()
                else if (name === "reset") run(["rp-settings", "reset"])
                else if (name === "lock") Quickshell.execDetached(["swaylock", "-f"])
                else if (name === "test-notify")
                    Quickshell.execDetached(["notify-send", "-a", "Settings", "Test notification",
                                             "This is how notifications look now."])
                else if (name === "dotfiles")
                    Quickshell.execDetached(["kitty", "--directory", Quickshell.env("HOME") + "/dotfiles", "yazi"])
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
                            root.error = text.slice(4).trim().split("\n").pop().replace(/^rp-settings: /, "")
                            errorTimer.restart()
                        }
                    }
                }
                // Po poslední změně si stáhnout skutečný stav (rp-settings hodnoty normalizuje)
                onExited: {
                    if (root.queue.length === 0) dumpProc.running = true
                    root.next()
                }
            }

            Timer { id: errorTimer; interval: 7000; onTriggered: root.error = "" }

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

            readonly property var powerModes: [
                { id: "battery",  icon: "󰁹", label: "Battery",  hint: "CPU powersave, dGPU capped at 40 W, video wallpaper suspended" },
                { id: "balanced", icon: "󰗑", label: "Balanced", hint: "Everyday default" },
                { id: "gaming",   icon: "󰊴", label: "Gaming",   hint: "Full power, dGPU clock floor, video wallpaper suspended" },
            ]

            readonly property var toolList: [
                { cmd: "pavucontrol",          icon: "󰕾", label: "Volume control",      hint: "pavucontrol" },
                { cmd: "blueman-manager",      icon: "󰂯", label: "Bluetooth",           hint: "blueman" },
                { cmd: "nm-connection-editor", icon: "󰛳", label: "Network connections", hint: "nm-connection-editor" },
                { cmd: "wdisplays",            icon: "󰍹", label: "Displays",            hint: "wdisplays (kanshi keeps profiles)" },
                { cmd: "nwg-look",             icon: "󰉼", label: "GTK appearance",      hint: "nwg-look — icons, fonts" },
                { cmd: "qt6ct",                icon: "󰙯", label: "Qt appearance",       hint: "qt6ct" },
                { cmd: "btop",                 icon: "󰍛", label: "System monitor",      hint: "btop in kitty", term: true },
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

            // Bez argumentu by apply-wallpaper-theme.sh u stejné tapety nic neudělal —
            // s cestou k aktuální tapetě téma přegeneruje
            Process {
                id: themeProc
                command: ["bash", "-c", "$HOME/.local/bin/apply-wallpaper-theme.sh "
                    + "\"$(cat \"${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/current-wallpaper-source\")\""]
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
                leftPadding: 4
            }

            // Řádek: popis vlevo, ovládací prvek vpravo
            component SettingRow: Item {
                id: row
                property string label
                property string hint
                property bool changed: false
                signal resetRequested()
                default property alias control: slot.data

                width: parent ? parent.width : 0
                height: Math.max(52, texts.implicitHeight + 22)

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
                        // Tečka = hodnota se liší od výchozí; kliknutí ji vrátí
                        Rectangle {
                            visible: row.changed
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 7
                            color: dotHover.hovered ? Qt.alpha(Colors.tertiary, 0.2) : "transparent"
                            Rectangle {
                                anchors.centerIn: parent
                                width: 6; height: 6; radius: 3
                                color: Colors.tertiary
                            }
                            HoverHandler { id: dotHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: row.resetRequested() }
                            ToolTip.visible: dotHover.hovered
                            ToolTip.text: "Changed — click to reset"
                            ToolTip.delay: 400
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
                property bool percent: false
                property string zero: ""
                property real live: value
                property bool dragging: false
                signal moved(real value)

                width: 280; height: 26
                onValueChanged: if (!dragging) live = value

                function at(x) {
                    const f = Math.max(0, Math.min(1, x / track.width))
                    const v = from + Math.round((to - from) * f / step) * step
                    return Number(Math.max(from, Math.min(to, v)).toFixed(Math.max(decimals, 2)))
                }

                function label(v) {
                    if (zero !== "" && v === 0) return zero
                    if (percent) return Math.round(v * 100) + "%"
                    return v.toFixed(decimals) + suffix
                }

                Item {
                    id: track
                    width: parent.width - 70
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
                        onWheel: event => sl.moved(Number(Math.max(sl.from, Math.min(sl.to,
                            sl.value + (event.angleDelta.y > 0 ? sl.step : -sl.step))).toFixed(Math.max(sl.decimals, 2))))
                    }
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 62
                    horizontalAlignment: Text.AlignRight
                    text: sl.label(sl.live)
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
                            width: Math.max(56, segText.implicitWidth + 22)
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

            // Rozbalovací seznam pro enumy s víc volbami (nebo dlouhými popisky)
            component Dropdown: ComboBox {
                id: dd
                property var options: []
                property var labels: []
                property string current
                signal picked(string value)

                width: 240
                height: 32
                model: options.map((o, i) => labels[i] ?? o)
                currentIndex: options.indexOf(current)
                onActivated: i => dd.picked(options[i])
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12

                background: Rectangle {
                    radius: 10
                    color: dd.hovered ? Qt.alpha(Colors.onSurface, 0.08) : Colors.surfaceContainerHighest
                    border.width: 1
                    border.color: dd.popup.visible ? Colors.primary : Colors.outlineVariant
                }
                contentItem: Text {
                    leftPadding: 12
                    rightPadding: 30
                    text: dd.displayText
                    font: dd.font
                    color: Colors.onSurface
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                indicator: Text {
                    x: dd.width - width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: dd.popup.visible ? "󰅃" : "󰅀"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Colors.onSurfaceVariant
                }
                delegate: ItemDelegate {
                    id: ddItem
                    required property var modelData
                    required property int index
                    width: dd.width - 12
                    height: 30
                    highlighted: dd.highlightedIndex === index
                    contentItem: Text {
                        text: ddItem.modelData
                        font: dd.font
                        color: ddItem.index === dd.currentIndex ? Colors.primary : Colors.onSurface
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        radius: 8
                        color: ddItem.highlighted ? Qt.alpha(Colors.primary, 0.18) : "transparent"
                    }
                }
                popup: Popup {
                    y: dd.height + 4
                    width: dd.width
                    implicitHeight: Math.min(contentItem.implicitHeight + 12, 320)
                    padding: 6
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: dd.popup.visible ? dd.delegateModel : null
                        currentIndex: dd.highlightedIndex
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                    background: Rectangle {
                        radius: 12
                        color: Colors.surfaceContainerHigh
                        border.width: 1
                        border.color: Colors.outlineVariant
                    }
                }
            }

            // Textové pole; zapisuje Enterem nebo po opuštění pole
            component TextBox: Rectangle {
                id: tb
                property string value
                signal committed(string value)

                width: 240
                height: 32
                radius: 10
                color: Colors.surfaceContainerHighest
                border.width: 1
                border.color: input.activeFocus ? Colors.primary : Colors.outlineVariant
                onValueChanged: if (!input.activeFocus) input.text = value

                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    text: tb.value
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Colors.onSurface
                    selectionColor: Qt.alpha(Colors.primary, 0.4)
                    clip: true
                    onAccepted: { tb.committed(text); focus = false }
                    onActiveFocusChanged: if (!activeFocus && text !== tb.value) tb.committed(text)
                    Keys.onEscapePressed: { text = tb.value; focus = false }
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

            // Jeden řádek z `pages`: vybere ovládací prvek podle typu klíče.
            // Obyčejná Component (ne inline `component`), aby viděla id `root`.
            property Component rowDelegate: Component {
                Column {
                    id: rd
                    required property var modelData
                    readonly property var d: modelData
                    readonly property var s: d.key ? (root.settings[d.key] ?? null) : null
                    readonly property string kind: d.kind ?? (s ? s.type : "")
                    width: parent ? parent.width : 0

                    // ── nastavení s klíčem
                    SettingRow {
                        visible: rd.s !== null
                        label: rd.d.label ?? ""
                        hint: (rd.d.where ? rd.d.where + " · " : "") + (rd.d.hint ?? "")
                        changed: rd.s?.changed ?? false
                        onResetRequested: root.reset(rd.d.key)

                        Loader {
                            active: rd.s !== null
                            sourceComponent: {
                                if (!rd.s) return null
                                switch (rd.s.type) {
                                case "bool": return toggleC
                                case "int":
                                case "float": return sliderC
                                case "string": return textC
                                case "enum": {
                                    const labels = rd.d.labels ?? rd.s.options
                                    const len = labels.reduce((a, l) => a + String(l).length, 0)
                                    return rd.s.options.length <= 4 && len <= 30 ? segC : dropC
                                }
                                }
                                return null
                            }
                        }
                    }

                    Component {
                        id: toggleC
                        Toggle {
                            checked: rd.s.value
                            onToggled: v => root.set(rd.d.key, v)
                        }
                    }
                    Component {
                        id: sliderC
                        Slider {
                            from: rd.s.min
                            to: rd.s.max
                            value: rd.s.value
                            step: rd.d.step ?? (rd.s.type === "float" ? 0.05 : 1)
                            decimals: rd.d.decimals ?? (rd.s.type === "float" ? 2 : 0)
                            suffix: rd.d.suffix ?? ""
                            percent: rd.d.percent ?? false
                            zero: rd.d.zero ?? ""
                            onMoved: v => root.set(rd.d.key, v)
                        }
                    }
                    Component {
                        id: segC
                        Segmented {
                            options: rd.s.options
                            labels: rd.d.labels ?? []
                            current: String(rd.s.value)
                            onPicked: v => root.set(rd.d.key, v)
                        }
                    }
                    Component {
                        id: dropC
                        Dropdown {
                            options: rd.s.options
                            labels: rd.d.labels ?? []
                            current: String(rd.s.value)
                            onPicked: v => root.set(rd.d.key, v)
                        }
                    }
                    Component {
                        id: textC
                        TextBox {
                            value: rd.s.value
                            onCommitted: v => root.set(rd.d.key, v)
                        }
                    }

                    // ── tlačítko
                    SettingRow {
                        visible: rd.kind === "button"
                        label: rd.d.label ?? ""
                        hint: (rd.d.where ? rd.d.where + " · " : "") + (rd.d.hint ?? "")
                        Button {
                            readonly property bool isTheme: rd.d.action === "theme"
                            icon: isTheme && root.applyingTheme ? "󰔟" : (rd.d.icon ?? "")
                            text: isTheme && root.applyingTheme ? "Applying…" : (rd.d.text ?? "")
                            busy: isTheme && root.applyingTheme
                            onClicked: root.action(rd.d.action)
                        }
                    }

                    // ── poznámka
                    Hint {
                        visible: rd.kind === "note"
                        width: parent.width
                        leftPadding: 14; rightPadding: 14; bottomPadding: 6
                        text: rd.d.text ?? ""
                    }

                    // ── theme moduly
                    Repeater {
                        model: rd.kind === "modules"
                            ? root.modules.filter(m => !/cache-hygiene|smoke-test|postprocess/.test(m.name)) : []
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

                    // ── power režimy
                    Hint {
                        visible: rd.kind === "power"
                        width: parent.width
                        leftPadding: 14; rightPadding: 14; bottomPadding: 8
                        text: "Power source: " + (root.powerSource || "?")
                            + ". Unplugging always drops to Battery; plugging back in restores your choice."
                    }
                    Repeater {
                        model: rd.kind === "power" ? root.powerModes : []
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

                    // ── nástroje
                    Repeater {
                        model: rd.kind === "tools" ? root.tools : []
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
                }
            }

            // ------------------------------------------------------------------ okno

            Rectangle {
                id: bg
                anchors.fill: parent
                color: Qt.alpha(Colors.surface, 0.86)
                focus: true
                Keys.onEscapePressed: {
                    if (root.query !== "") search.text = ""
                    else outer.hide()
                }
                Keys.onPressed: event => {
                    // Ctrl+F hledá, Ctrl+Tab / Ctrl+Shift+Tab listují stránky
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (ctrl && event.key === Qt.Key_F) {
                        search.forceActiveFocus()
                    } else if (ctrl && event.key === Qt.Key_Tab) {
                        persist.page = (persist.page + 1) % root.pages.length
                    } else if (ctrl && event.key === Qt.Key_Backtab) {
                        persist.page = (persist.page - 1 + root.pages.length) % root.pages.length
                    } else return
                    event.accepted = true
                }

                // Klik do prázdna vezme fokus textovým polím (a tím je zapíše)
                TapHandler { onTapped: bg.forceActiveFocus() }

                // ── Postranní panel
                Rectangle {
                    id: sidebar
                    width: 236
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
                            bottomPadding: 12
                            font.family: root.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            color: Colors.onSurface
                        }

                        // Hledání napříč stránkami
                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: 10
                            color: Colors.surfaceContainerHighest
                            border.width: 1
                            border.color: search.activeFocus ? Colors.primary : "transparent"

                            Text {
                                id: searchIcon
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                text: "󰍉"
                                font.family: root.fontFamily
                                font.pixelSize: 14
                                color: Colors.onSurfaceVariant
                            }
                            TextInput {
                                id: search
                                anchors {
                                    left: searchIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                color: Colors.onSurface
                                selectionColor: Qt.alpha(Colors.primary, 0.4)
                                clip: true
                                onTextChanged: root.query = text
                                Keys.onEscapePressed: { text = ""; bg.forceActiveFocus() }
                                Text {
                                    visible: search.text === ""
                                    text: "Search  (Ctrl+F)"
                                    font: search.font
                                    color: Colors.outline
                                }
                            }
                        }

                        Item { width: 1; height: 8 }

                        Repeater {
                            model: root.pages
                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool sel: root.query === "" && persist.page === index
                                width: parent.width
                                height: 38
                                radius: 10
                                color: sel ? Qt.alpha(Colors.primary, 0.18)
                                    : navHover.hovered ? Qt.alpha(Colors.onSurface, 0.05) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                HoverHandler { id: navHover }

                                Row {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    spacing: 12
                                    Text {
                                        width: 18
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
                                    onClicked: { search.text = ""; persist.page = index }
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
                        leftMargin: 24; rightMargin: 24; topMargin: 22
                    }

                    Text {
                        id: pageTitle
                        leftPadding: 4
                        text: root.query !== ""
                            ? (root.results.length + (root.results.length === 1 ? " result" : " results"))
                            : root.pages[persist.page].label
                        font.family: root.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        color: Colors.onSurface
                    }

                    Flickable {
                        id: flick
                        anchors { top: pageTitle.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
                        contentHeight: pageCol.implicitHeight + 32
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: pageCol
                            width: flick.width - 12
                            spacing: 2

                            // Stránka: sekce s nadpisem a řádky
                            Repeater {
                                model: root.query === "" ? root.pages[persist.page].sections : []
                                Column {
                                    required property var modelData
                                    width: pageCol.width
                                    spacing: 2
                                    Heading { text: modelData.title }
                                    Repeater {
                                        model: modelData.rows
                                        delegate: root.rowDelegate
                                    }
                                }
                            }

                            // Výsledky hledání
                            Repeater {
                                model: root.results
                                delegate: root.rowDelegate
                            }
                            Hint {
                                visible: root.query !== "" && root.results.length === 0
                                leftPadding: 4; topPadding: 12
                                text: "Nothing matches “" + root.query + "”."
                            }
                        }
                    }
                }

                // Při přepnutí stránky nahoru
                Connections {
                    target: persist
                    function onPageChanged() { flick.contentY = 0 }
                }

                // ── Chybová hláška (např. niri odmítlo změnu)
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
    }
}
