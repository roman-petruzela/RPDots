import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "Colors.js" as Colors
import "settings"

Scope {
    id: outer
    reloadableId: "rpSettingsScope"

    readonly property var pageList: [
        { id: "network", group: "CONNECTIONS", icon: "󰛳", label: "Network", view: "network",
          keywords: "wifi wi-fi ethernet ip address dns vpn proton airplane speed test public" },
        { id: "sound", group: "CONNECTIONS", icon: "󰕾", label: "Sound", view: "sound",
          keywords: "audio volume output input microphone speakers headphones apps profile" },
        { id: "bluetooth", group: "CONNECTIONS", icon: "󰂯", label: "Bluetooth", view: "bluetooth",
          keywords: "pair devices headphones controller battery" },
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
                { key: "niri.shadow_offset", label: "Vertical offset", hint: "Positive drops the shadow below the window.", suffix: " px" },
            ]},
            { title: "BORDER", rows: [
                { key: "niri.border", label: "Window border", hint: "A solid border inside the window edge, in the wallpaper's colors. Unlike the focus ring it takes up space." },
                { key: "niri.border_width", label: "Border width", suffix: " px" },
            ]},
            { title: "TABBED COLUMNS", rows: [
                { key: "niri.tab_indicator", label: "Tab indicator", hint: "Bar showing the tabs of a tabbed column (Mod+W)." },
                { key: "niri.tab_position", label: "Position", labels: ["Left", "Right", "Top", "Bottom"] },
                { key: "niri.tab_width", label: "Thickness", suffix: " px" },
                { key: "niri.tab_single", label: "Hide with a single tab" },
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
            { title: "SPACE", rows: [
                { key: "niri.struts_h", label: "Side margins", hint: "Keep this much free on the left and right; windows still scroll into it.", suffix: " px", step: 4 },
                { key: "niri.struts_v", label: "Top & bottom margins", suffix: " px", step: 4 },
                { key: "niri.insert_hint", label: "Insert hint", hint: "Show where a dragged window will land." },
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
            { title: "DECORATIONS", rows: [
                { key: "niri.prefer_no_csd", label: "Ask apps not to draw their own title bars", hint: "Apps started afterwards get plain windows; some (Zed, browsers) draw theirs anyway." },
                { key: "niri.hotkey_overlay", label: "Shortcut cheat sheet at login", hint: "niri's overlay of important shortcuts (Mod+Shift+/ shows it any time)." },
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
        { id: "apps", group: "APPS", icon: "󰀻", label: "Applications", view: "apps",
          keywords: "installed default open with browser mail pdf autostart startup login launcher hide uninstall" },
        { id: "history", group: "APPS", icon: "󰋚", label: "History", view: "history",
          keywords: "notifications clipboard terminal shell zsh commands recent" },
        { id: "nightlight", group: "PERSONALIZATION", icon: "󰖔", label: "Night light", view: "nightlight",
          keywords: "blue light warm color temperature evening wlsunset redshift" },
        { id: "accessibility", group: "PERSONALIZATION", icon: "󰖷", label: "Accessibility", sections: [
            { title: "VISION", rows: [
                { key: "a11y.text_scale", label: "Text size", hint: "Scales text in GTK apps (Thunar, pavucontrol…), live.", percent: true, step: 0.05 },
                { key: "cursor.size", label: "Cursor size", suffix: " px", step: 2 },
                { key: "niri.focus_ring_width", label: "Focus ring", hint: "A thicker ring makes the focused window easier to spot.", suffix: " px", zero: "Off" },
                { kind: "button", action: "orca", label: "Screen reader", hint: "Orca reads the screen aloud (needs the orca package). Super+Alt+S toggles it too.", icon: "󰗅", text: "Start / stop" },
            ]},
            { title: "MOTION", rows: [
                { key: "niri.animations", label: "Animations", hint: "Turn off to reduce motion." },
                { key: "niri.anim_slowdown", label: "Animation duration", step: 0.05, suffix: "×" },
            ]},
            { title: "TIMING", rows: [
                { key: "notify.timeout", label: "Keep notifications for", suffix: " s", zero: "Until dismissed" },
                { key: "input.repeat_delay", label: "Key repeat delay", hint: "Longer avoids accidental repeated letters.", suffix: " ms", step: 25 },
                { key: "input.repeat_rate", label: "Key repeat rate", suffix: "/s" },
            ]},
        ]},
        { id: "shortcuts", group: "APPS", icon: "󰌌", label: "Shortcuts", view: "shortcuts",
          keywords: "keybindings keys binds hotkeys remap niri" },
        { id: "displays", group: "SYSTEM", icon: "󰍹", label: "Displays", view: "displays",
          keywords: "monitor screen resolution refresh rate hz scale rotation orientation vrr arrange" },
        { id: "about", group: "SYSTEM", icon: "󰋼", label: "About", view: "about", keywords: "system info hardware cpu gpu memory disk kernel version" },
        { id: "updates", group: "SYSTEM", icon: "󰚰", label: "Updates", view: "updates", keywords: "upgrade pacman paru aur flatpak" },
        { id: "packages", group: "SYSTEM", icon: "󰏖", label: "Packages", view: "packages", keywords: "install remove uninstall pacman aur flatpak orphans cache" },
        { id: "firewall", group: "SYSTEM", icon: "󰒃", label: "Firewall", view: "firewall", keywords: "firewalld ports services security network" },
        { id: "power", group: "SYSTEM", icon: "󰂄", label: "Power", sections: [
            { title: "MODE", rows: [ { kind: "power" } ]},
        ]},
        { id: "storage", icon: "󰋊", label: "Storage", view: "storage",
          keywords: "disk space clean cache trash smart health free" },
        { id: "timelang", icon: "󰥔", label: "Time & language", view: "timelang",
          keywords: "date clock timezone ntp locale language region formats" },
        { id: "account", icon: "󰀄", label: "Account", view: "account",
          keywords: "user password name shell keyring login" },
        { id: "privacy", icon: "󰒃", label: "Privacy", view: "privacy",
          keywords: "microphone camera screen sharing recent files thumbnails" },
        { id: "backup", icon: "󰁯", label: "Backup", view: "backup",
          keywords: "snapshot snapper btrfs restore export import" },
        { id: "printers", icon: "󰐪", label: "Printers", view: "printers",
          keywords: "print cups queue scanner" },
        { id: "gaming", icon: "󰊴", label: "Gaming", view: "gaming",
          keywords: "gamemode mangohud fps overlay steam gamescope" },
        { id: "tools", group: "SYSTEM", icon: "󰒓", label: "Tools", sections: [
            { title: "SYSTEM TOOLS", rows: [ { kind: "tools" } ]},
            { title: "MAINTENANCE", rows: [
                { kind: "button", action: "reset", label: "Reset everything", hint: "Forget everything set in this window (settings.json).", icon: "󰦛", text: "Reset" },
                { kind: "button", action: "dotfiles", label: "Open dotfiles", hint: "~/dotfiles in yazi", icon: "󰉋", text: "Open" },
            ]},
        ]},
    ]

    readonly property var groups: [
        { name: "SYSTEM", ids: ["about", "updates", "packages", "storage", "power", "backup", "tools"] },
        { name: "DEVICES", ids: ["displays", "sound", "bluetooth", "keyboard", "mouse", "printers"] },
        { name: "NETWORK", ids: ["network", "firewall"] },
        { name: "APPS", ids: ["apps", "shortcuts", "history", "gaming"] },
        { name: "PERSONALIZATION", ids: ["appearance", "windows", "theme", "nightlight", "notifications"] },
        { name: "ACCOUNT", ids: ["account", "privacy", "timelang", "accessibility"] },
    ]
    readonly property var pages: {
        const gs = Array.from(groups), all = Array.from(pageList)
        const listed = [].concat(...gs.map(g => Array.from(g.ids)))
        const out = [].concat(...gs.map(g => Array.from(g.ids).map(id => all.find(p => p.id === id))
                                           .filter(p => p).map(p => Object.assign({}, p, { group: g.name }))))
        return out.concat(all.filter(p => !listed.includes(p.id)).map(p => Object.assign({}, p, { group: "OTHER" })))
    }

    PersistentProperties {
        id: persist
        reloadableId: "rpSettings"
        property bool open: false
        property int page: 0
    }

    function open() {
        if (!persist.open) persist.page = Math.max(0, pages.findIndex(p => p.id === "about"))
        persist.open = true
    }
    function hide()   { persist.open = false }
    function toggle() { if (persist.open) hide(); else open() }

    function openPage(name) {
        const i = pages.findIndex(p => p.id === name || p.label.toLowerCase() === name)
        if (i < 0) return false
        persist.page = i
        persist.open = true
        return true
    }

    LazyLoader {
        active: persist.open

        FloatingWindow {
            id: root

            readonly property string fontFamily: "JetBrainsMono Nerd Font"
            readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

            title: "RPSettings"
            implicitWidth: 980
            implicitHeight: 720
            minimumSize: Qt.size(860, 600)
            visible: true
            color: "transparent"
            onClosed: outer.hide()

            BackgroundEffect.blurRegion: Region { item: bg; radius: 16 }

            property var settings: ({})
            property var modules: []
            property string error: ""
            property string powerMode: "?"
            property string powerSource: ""
            property var tools: []
            property bool applyingTheme: false
            property string query: ""
            property var updatesCache: null
            property alias job: jobPanel

            readonly property var pages: outer.pages ?? []
            readonly property var page: pages[persist.page] ?? pages[0] ?? ({ id: "", label: "", sections: [] })

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

            property bool errorIsInfo: false

            function showError(msg) {
                errorIsInfo = false
                error = msg
                errorTimer.restart()
            }

            function showInfo(msg) {
                errorIsInfo = true
                error = msg
                errorTimer.interval = 2500
                errorTimer.restart()
            }

            function goTo(id) {
                search.text = ""
                persist.page = pages.findIndex(p => p.id === id)
            }

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
                else if (name === "orca") Quickshell.execDetached(["sh", "-c", "pkill orca || exec orca"])
                else if (name === "test-notify")
                    Quickshell.execDetached(["notify-send", "-a", "Settings", "Test notification",
                                             "This is how notifications look now."])
                else if (name === "dotfiles")
                    Quickshell.execDetached(["kitty", "--directory", Quickshell.env("HOME") + "/dotfiles", "yazi"])
            }

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
                onExited: {
                    if (root.queue.length === 0) dumpProc.running = true
                    root.next()
                }
            }

            Timer { id: errorTimer; interval: 7000; onTriggered: { root.error = ""; interval = 7000 } }

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
                command: ["bash", "-c",
                    'c="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"; '
                    + 'setsid -f "$HOME/.local/bin/apply-wallpaper-theme.sh" "$(cat "$c/current-wallpaper-source")" >/dev/null 2>&1; '
                    + 'sleep 1; while [ -d "$c/theme-apply.lock.d" ]; do sleep 0.5; done']
                onExited: root.applyingTheme = false
            }

            function applyTheme() {
                if (themeProc.running) return
                applyingTheme = true
                themeProc.running = true
            }

            property Component rowDelegate: Component {
                Column {
                    id: rd
                    required property var modelData
                    readonly property var d: modelData
                    readonly property var s: d.key ? (root.settings[d.key] ?? null) : null
                    readonly property string kind: d.kind ?? (s ? s.type : "")
                    width: parent ? parent.width : 0

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

                    SHint {
                        visible: rd.kind === "note"
                        width: parent.width
                        leftPadding: 14; rightPadding: 14; bottomPadding: 6
                        text: rd.d.text ?? ""
                    }

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

                TapHandler { onTapped: bg.forceActiveFocus() }

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

                    SWheel { flick: navFlick }
                    Flickable {
                        id: navFlick
                        anchors { left: parent.left; right: parent.right; top: nav.bottom; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 14 }
                        contentHeight: navCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: SScrollBar {}

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

                Item {
                    id: contentArea
                    anchors {
                        top: parent.top; bottom: parent.bottom
                        left: sidebar.right; right: parent.right
                        leftMargin: 24; rightMargin: 12; topMargin: 20
                    }

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

                    SWheel { flick: flick }
                    Flickable {
                        id: flick
                        visible: root.query !== "" || !root.page.view
                        anchors { top: pageTitle.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: jobPanel.occupied }
                        contentHeight: pageCol.implicitHeight + 32
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: SScrollBar {}

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

                    Loader {
                        anchors { top: pageTitle.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 12 + jobPanel.occupied }
                        active: root.query === "" && !!root.page.view
                        sourceComponent: ({ about: aboutC, updates: updatesC, packages: packagesC, firewall: firewallC,
                                            network: networkC, sound: soundC, bluetooth: bluetoothC,
                                            displays: displaysC, shortcuts: shortcutsC,
                                            apps: appsC, history: historyC, nightlight: nightlightC,
                                            storage: storageC, timelang: timelangC, account: accountC,
                                            privacy: privacyC, backup: backupC, printers: printersC,
                                            gaming: gamingC })[root.page.view] ?? null
                    }
                    Component { id: aboutC; AboutPage { host: root } }
                    Component { id: updatesC; UpdatesPage { host: root } }
                    Component { id: packagesC; PackagesPage { host: root } }
                    Component { id: firewallC; FirewallPage { host: root } }
                    Component { id: networkC; NetworkPage { host: root } }
                    Component { id: soundC; SoundPage { host: root } }
                    Component { id: bluetoothC; BluetoothPage { host: root } }
                    Component { id: displaysC; DisplaysPage { host: root } }
                    Component { id: shortcutsC; ShortcutsPage { host: root } }
                    Component { id: appsC; AppsPage { host: root } }
                    Component { id: historyC; HistoryPage { host: root } }
                    Component { id: nightlightC; NightLightPage { host: root } }
                    Component { id: storageC; StoragePage { host: root } }
                    Component { id: timelangC; TimeLanguagePage { host: root } }
                    Component { id: accountC; AccountPage { host: root } }
                    Component { id: privacyC; PrivacyPage { host: root } }
                    Component { id: backupC; BackupPage { host: root } }
                    Component { id: printersC; PrintersPage { host: root } }
                    Component { id: gamingC; GamingPage { host: root } }

                    SJob {
                        id: jobPanel
                        x: -24
                        width: parent.width + 24 + 12
                        fullHeight: Math.min(parent.height * 0.6, 420)
                    }
                }

                Connections {
                    target: persist
                    function onPageChanged() { flick.contentY = 0 }
                }

                Rectangle {
                    visible: root.error !== ""
                    anchors { bottom: parent.bottom; horizontalCenter: contentArea.horizontalCenter; bottomMargin: 18 }
                    width: Math.min(contentArea.width, errText.implicitWidth + 32)
                    height: errText.implicitHeight + 18
                    radius: 10
                    color: Qt.alpha(root.errorIsInfo ? Colors.primary : Colors.errorColor, 0.18)
                    border.width: 1
                    border.color: Qt.alpha(root.errorIsInfo ? Colors.primary : Colors.errorColor, 0.6)
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
