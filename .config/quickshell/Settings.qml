import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "Colors.js" as Colors
import "settings"

// Okno nastavení ricu (Mod+S, `rp-shell settings toggle`, v launcheru jako
// „Settings“). Je to obyčejné plovoucí okno (xdg toplevel), ne vrstva — dá se
// přesouvat, niri mu kreslí otevírací animaci a window-rule v config.kdl ho
// otevře plovoucí. `rp-shell settings <id stránky>` ho otevře rovnou na stránce.
//
// Dva druhy stránek:
//  - nastavení (Personalization): typy, rozsahy, volby i výchozí stavy dodává
//    `rp-settings dump`, změny jdou přes `rp-settings set`, které je ověří
//    a aplikuje. Tady je jen rozložení — `pages` říká, který klíč patří na
//    kterou stránku a jak se jmenuje; ovládací prvek se vybere podle typu
//    (bool → přepínač, číslo → posuvník, enum → segmenty/rozbalovací seznam,
//    string → textové pole). Nová volba = klíč ve schématu rp-settings + řádek tady.
//  - systémové (`view`): vlastní komponenty v settings/ (AboutPage, UpdatesPage,
//    PackagesPage, FirewallPage) nad `rp-sys`. Root akce jdou přes polkit a jejich
//    log ukazuje sdílený panel `job` (settings/SJob.qml).
//
// Ovládací prvky (SRow, SToggle, SSlider, …) jsou v settings/, aby je sdílely
// obě skupiny stránek.
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
        { id: "network", group: "CONNECTIONS", icon: "󰛳", label: "Network", view: "network",
          keywords: "wifi wi-fi ethernet ip address dns vpn proton airplane speed test public" },
        { id: "sound", group: "CONNECTIONS", icon: "󰕾", label: "Sound", view: "sound",
          keywords: "audio volume output input microphone speakers headphones apps profile" },
        { id: "appearance", group: "PERSONALIZATION", icon: "󰏘", label: "Appearance", sections: [
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
        { id: "windows", group: "PERSONALIZATION", icon: "󰕰", label: "Windows", sections: [
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
        { id: "theme", group: "PERSONALIZATION", icon: "󰸌", label: "Theme", sections: [
            { title: "COLORS", rows: [
                { kind: "button", action: "wallpaper", label: "Wallpaper", hint: "Pick a wallpaper; the whole theme follows it.", icon: "󰸉", text: "Choose…" },
                { key: "theme.scheme", label: "Color scheme", hint: "How matugen derives the palette from the wallpaper.",
                  labels: ["Tonal spot", "Content", "Expressive", "Fidelity", "Fruit salad", "Rainbow", "Neutral"] },
                { key: "theme.contrast", label: "Contrast", hint: "−1 softest, 0 standard, 1 strongest.", step: 0.1, decimals: 1 },
                { key: "theme.mono_mode", label: "Monochrome scheme", hint: "Grey palette for black-and-white wallpapers.", labels: ["Auto", "On", "Off"] },
                { kind: "button", action: "theme", label: "Regenerate theme", hint: "Scheme, contrast and monochrome apply on the next regenerate.", icon: "󰑓", text: "Apply now" },
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
        { id: "keyboard", group: "PERSONALIZATION", icon: "󰌌", label: "Keyboard", sections: [
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
        { id: "mouse", group: "PERSONALIZATION", icon: "󰍽", label: "Mouse & touchpad", sections: [
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
                { key: "input.touchpad_click", label: "Click method", hint: "Fingers: 2 fingers = right, 3 = middle.",
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
                { key: "cursor.theme", label: "Cursor theme", hint: "Changes right away where niri draws the cursor; apps that draw their own (waybar, GTK3, XWayland, this window) pick it up after a restart." },
                { key: "cursor.size", label: "Cursor size", suffix: " px", step: 2 },
                { key: "cursor.hide_typing", label: "Hide while typing", hint: "Can confuse mouselook in some Wine games." },
                { key: "cursor.hide_after", label: "Hide when idle", hint: "Hide the pointer after this long without movement.", suffix: " s", zero: "Never" },
            ]},
        ]},
        { id: "notifications", group: "PERSONALIZATION", icon: "󰂚", label: "Notifications & idle", sections: [
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
        { id: "about", group: "SYSTEM", icon: "󰋼", label: "About", view: "about", keywords: "system info hardware cpu gpu memory disk kernel version" },
        { id: "updates", group: "SYSTEM", icon: "󰚰", label: "Updates", view: "updates", keywords: "upgrade pacman paru aur flatpak" },
        { id: "packages", group: "SYSTEM", icon: "󰏖", label: "Packages", view: "packages", keywords: "install remove uninstall pacman aur flatpak orphans cache" },
        { id: "firewall", group: "SYSTEM", icon: "󰒃", label: "Firewall", view: "firewall", keywords: "firewalld ports services security network" },
        { id: "power", group: "SYSTEM", icon: "󰂄", label: "Power", sections: [
            { title: "MODE", rows: [ { kind: "power" } ]},
        ]},
        { id: "tools", group: "SYSTEM", icon: "󰒓", label: "Tools", sections: [
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
            implicitWidth: 980
            implicitHeight: 720
            minimumSize: Qt.size(860, 600)
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
            // Výsledek `rp-sys updates` — přežije přepnutí stránky (kontrola trvá ~15 s)
            property var updatesCache: null
            property alias job: jobPanel

            readonly property var pages: outer.pages
            readonly property var page: pages[persist.page]

            // Hledání: řádky s klíčem nebo tlačítkem a systémové stránky podle názvu
            readonly property var results: {
                const q = query.trim().toLowerCase()
                if (q === "") return []
                const words = q.split(/\s+/)
                const out = []
                for (const p of pages) {
                    if (p.view) {
                        const hay = [p.label, p.keywords ?? ""].join(" ").toLowerCase()
                        if (words.every(w => hay.includes(w)))
                            out.push({ kind: "page", label: p.label, hint: "Open " + p.label, icon: p.icon, pageId: p.id, where: "System" })
                        continue
                    }
                    for (const s of p.sections)
                        for (const r of s.rows) {
                            if (!r.key && r.kind !== "button") continue
                            const hay = [r.label, r.hint, r.key, p.label, s.title].join(" ").toLowerCase()
                            if (words.every(w => hay.includes(w)))
                                out.push(Object.assign({}, r, { where: p.label }))
                        }
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

            function showError(msg) {
                error = msg
                errorTimer.restart()
            }

            function goTo(id) {
                search.text = ""
                persist.page = pages.findIndex(p => p.id === id)
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
                        if (text.startsWith("ERR "))
                            root.showError(text.slice(4).trim().split("\n").pop().replace(/^rp-settings: /, ""))
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
                            root.showError("rp-settings dump failed")
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
                    SRow {
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
                        SToggle {
                            checked: rd.s.value
                            onToggled: v => root.set(rd.d.key, v)
                        }
                    }
                    Component {
                        id: sliderC
                        SSlider {
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
                        SSegmented {
                            options: rd.s.options
                            labels: rd.d.labels ?? []
                            current: String(rd.s.value)
                            onPicked: v => root.set(rd.d.key, v)
                        }
                    }
                    Component {
                        id: dropC
                        SDropdown {
                            options: rd.s.options
                            labels: rd.d.labels ?? []
                            current: String(rd.s.value)
                            onPicked: v => root.set(rd.d.key, v)
                        }
                    }
                    Component {
                        id: textC
                        STextBox {
                            value: rd.s.value
                            onCommitted: v => root.set(rd.d.key, v)
                        }
                    }

                    // ── tlačítko
                    SRow {
                        visible: rd.kind === "button"
                        label: rd.d.label ?? ""
                        hint: (rd.d.where ? rd.d.where + " · " : "") + (rd.d.hint ?? "")
                        SButton {
                            readonly property bool isTheme: rd.d.action === "theme"
                            icon: isTheme && root.applyingTheme ? "󰔟" : (rd.d.icon ?? "")
                            text: isTheme && root.applyingTheme ? "Applying…" : (rd.d.text ?? "")
                            busy: isTheme && root.applyingTheme
                            onClicked: root.action(rd.d.action)
                        }
                    }

                    // ── odkaz na systémovou stránku (výsledek hledání)
                    SRow {
                        visible: rd.kind === "page"
                        icon: rd.d.icon ?? ""
                        label: rd.d.label ?? ""
                        hint: rd.d.where ? rd.d.where + " page" : ""
                        SButton {
                            icon: "󰁔"; text: "Open"
                            onClicked: root.goTo(rd.d.pageId)
                        }
                    }

                    // ── poznámka
                    SHint {
                        visible: rd.kind === "note"
                        width: parent.width
                        leftPadding: 14; rightPadding: 14; bottomPadding: 6
                        text: rd.d.text ?? ""
                    }

                    // ── theme moduly
                    Repeater {
                        model: rd.kind === "modules"
                            ? root.modules.filter(m => !/cache-hygiene|smoke-test|postprocess/.test(m.name)) : []
                        SRow {
                            required property var modelData
                            label: modelData.name.replace(/^\d+-/, "").replace(/\.sh$/, "")
                            hint: modelData.requires !== "" ? "needs " + modelData.requires : ""
                            height: 46
                            SToggle {
                                checked: modelData.enabled
                                onToggled: v => root.setModule(modelData.name, v)
                            }
                        }
                    }

                    // ── power režimy
                    SHint {
                        visible: rd.kind === "power"
                        width: parent.width
                        leftPadding: 14; rightPadding: 14; bottomPadding: 8
                        text: "Power source: " + (root.powerSource || "?")
                            + ". Unplugging always drops to Battery; plugging back in restores your choice."
                    }
                    Repeater {
                        model: rd.kind === "power" ? root.powerModes : []
                        SRow {
                            required property var modelData
                            icon: modelData.icon
                            label: modelData.label
                            hint: modelData.hint
                            SToggle {
                                checked: root.powerMode === modelData.id
                                onToggled: root.setPower(modelData.id)
                            }
                        }
                    }

                    // ── nástroje
                    Repeater {
                        model: rd.kind === "tools" ? root.tools : []
                        SRow {
                            required property var modelData
                            icon: modelData.icon
                            label: modelData.label
                            hint: modelData.hint
                            SButton {
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
                    else if (jobPanel.open && !jobPanel.running) jobPanel.open = false
                    else outer.hide()
                }
                Keys.onPressed: event => {
                    // Ctrl+F hledá, Ctrl+Tab / Ctrl+Shift+Tab listují stránky
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (ctrl && event.key === Qt.Key_F) {
                        search.inputItem.forceActiveFocus()
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
                    width: 240
                    anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                    color: Qt.alpha(Colors.surfaceContainer, 0.7)

                    Rectangle {
                        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                        width: 1
                        color: Qt.alpha(Colors.outlineVariant, 0.6)
                    }

                    Column {
                        id: nav
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 20 }
                        spacing: 2

                        Item {
                            width: parent.width
                            height: 40
                            SLabel {
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                text: "Settings"
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                        }

                        STextBox {
                            id: search
                            width: parent.width
                            icon: "󰍉"
                            placeholder: "Search  (Ctrl+F)"
                            commitOnBlur: false
                            onEdited: v => root.query = v
                        }

                    }

                    // Stránky — posuvné, ať se vejdou i na nižší okno
                    Flickable {
                        id: navFlick
                        anchors { left: parent.left; right: parent.right; top: nav.bottom; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 14 }
                        contentHeight: navCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: navCol
                            width: navFlick.width
                            spacing: 2

                            Repeater {
                                model: root.pages
                                Column {
                                    required property var modelData
                                    required property int index
                                    readonly property bool sel: root.query === "" && persist.page === index
                                    readonly property bool firstInGroup: index === 0 || root.pages[index - 1].group !== modelData.group
                                    width: navCol.width

                                    // Nadpis skupiny (Personalization / System)
                                    Item {
                                        visible: firstInGroup
                                        width: parent.width
                                        height: 34
                                        SHeading {
                                            anchors.bottom: parent.bottom
                                            leftPadding: 12; topPadding: 0; bottomPadding: 6
                                            text: modelData.group
                                            color: Colors.outline
                                            font.pixelSize: 10
                                        }
                                    }

                                    // Položka: ikona i text svisle na středu (Row by je zarovnal nahoru)
                                    Rectangle {
                                        width: parent.width
                                        height: 36
                                        radius: 10
                                        color: sel ? Qt.alpha(Colors.primary, 0.18)
                                            : navHover.hovered ? Qt.alpha(Colors.onSurface, 0.05) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        HoverHandler { id: navHover }

                                        Text {
                                            id: navIcon
                                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                            width: 20
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData.icon
                                            font.family: root.fontFamily
                                            font.pixelSize: 16
                                            color: sel ? Colors.primary : Colors.onSurfaceVariant
                                        }
                                        Text {
                                            anchors { left: navIcon.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                            text: modelData.label
                                            elide: Text.ElideRight
                                            font.family: root.fontFamily
                                            font.pixelSize: 13
                                            font.weight: sel ? Font.Medium : Font.Normal
                                            color: sel ? Colors.onSurface : Colors.onSurfaceVariant
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.goTo(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                }

                // ── Obsah
                Item {
                    id: contentArea
                    anchors {
                        top: parent.top; bottom: parent.bottom
                        left: sidebar.right; right: parent.right
                        leftMargin: 24; rightMargin: 12; topMargin: 20
                    }

                    // Nadpis ve stejné výšce jako „Settings“ vlevo
                    Item {
                        id: pageTitle
                        width: parent.width
                        height: 40
                        SLabel {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            text: root.query !== ""
                                ? (root.results.length + (root.results.length === 1 ? " result" : " results"))
                                : root.page.label
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                        }
                    }

                    // Stránky nastavení: sekce s nadpisem a řádky
                    Flickable {
                        id: flick
                        visible: root.query !== "" || !root.page.view
                        anchors { top: pageTitle.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }
                        contentHeight: pageCol.implicitHeight + 32
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        Column {
                            id: pageCol
                            width: flick.width - 12
                            spacing: 2

                            Repeater {
                                model: root.query === "" && !root.page.view ? root.page.sections : []
                                Column {
                                    required property var modelData
                                    width: pageCol.width
                                    spacing: 2
                                    SHeading { text: modelData.title }
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
                            SHint {
                                visible: root.query !== "" && root.results.length === 0
                                leftPadding: 14; topPadding: 12
                                text: "Nothing matches “" + root.query + "”."
                            }
                        }
                    }

                    // Systémové stránky (vlastní rozložení)
                    Loader {
                        anchors { top: pageTitle.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 12 }
                        active: root.query === "" && !!root.page.view
                        sourceComponent: ({ about: aboutC, updates: updatesC, packages: packagesC, firewall: firewallC,
                                            network: networkC, sound: soundC })[root.page.view] ?? null
                    }
                    Component { id: aboutC; AboutPage { host: root } }
                    Component { id: updatesC; UpdatesPage { host: root } }
                    Component { id: packagesC; PackagesPage { host: root } }
                    Component { id: firewallC; FirewallPage { host: root } }
                    Component { id: networkC; NetworkPage { host: root } }
                    Component { id: soundC; SoundPage { host: root } }

                    // Log akcí (aktualizace, instalace, firewall) — vyjede zespodu
                    SJob {
                        id: jobPanel
                        x: 0
                        width: parent.width - 12
                        height: Math.min(parent.height * 0.6, 420)
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
