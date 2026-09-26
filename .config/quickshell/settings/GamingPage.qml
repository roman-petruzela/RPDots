import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Hraní: stav GameMode, MangoHud (pár nejčastějších voleb přímo v
// ~/.config/MangoHud/MangoHud.conf + zapnutí ve všech Vulkan hrách přes
// environment.d), rychlý přechod na power režim a VRR. Backend `rp-sys gaming`.
Item {
    id: page
    required property var host

    property var g: null

    function reload() { proc.running = false; proc.running = true }
    Component.onCompleted: reload()
    Timer { interval: 4000; running: true; repeat: true; onTriggered: page.reload() }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "gaming"]
        stdout: StdioCollector { onStreamFinished: { try { page.g = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: actProc
        stderr: StdioCollector { onStreamFinished: if (text.trim()) page.host.showError(text.trim()) }
        onExited: page.reload()
    }
    function sys(args) {
        actProc.running = false
        actProc.command = [Quickshell.env("HOME") + "/.local/bin/rp-sys"].concat(args)
        actProc.running = true
    }

    readonly property var mh: g?.mangohud ?? ({})
    function has(t) { return (g?.tools ?? []).includes(t) }

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

            SCard {
                width: parent.width
                height: 92
                Text {
                    id: pad
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    text: "󰊴"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 32
                    color: page.g?.gamemode ? Colors.primary : Colors.onSurfaceVariant
                }
                Column {
                    anchors { left: pad.right; leftMargin: 18; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel {
                        text: page.g?.gamemode ? "GameMode is active" : "GameMode is idle"
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    SHint {
                        width: parent.width
                        text: "Turns on by itself for games started with `gamemoderun %command%` (Steam launch options)."
                    }
                }
            }

            SHeading { text: "PERFORMANCE" }
            SRow {
                label: "Power mode"
                hint: "Gaming: full power, dGPU clock floor, video wallpaper paused."
                SButton { icon: "󰁔"; text: "Power"; onClicked: page.host.goTo("power") }
            }
            SRow {
                label: "Variable refresh rate"
                hint: "Per display, on the Displays page (on demand = only for games)."
                SButton { icon: "󰁔"; text: "Displays"; onClicked: page.host.goTo("displays") }
            }

            SHeading { text: "MANGOHUD OVERLAY" }
            SRow {
                label: "In every Vulkan game"
                hint: "Sets MANGOHUD=1 for the session (new games; full effect after logging in again). Otherwise use `mangohud %command%`."
                SToggle {
                    checked: page.g?.mangoEverywhere ?? false
                    onToggled: v => page.sys(["mango-everywhere", v ? "on" : "off"])
                }
            }
            SRow {
                label: "FPS limit"
                hint: "0 = unlimited."
                SSlider {
                    from: 0; to: 240; step: 5
                    value: Number(String(page.mh.fps_limit ?? "0").split(",")[0]) || 0
                    zero: "Off"
                    onMoved: v => page.sys(["mango-set", "fps_limit", String(Math.round(v))])
                }
            }
            SRow {
                label: "Position"
                SDropdown {
                    width: 200
                    options: ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"]
                    labels: ["Top left", "Top center", "Top right", "Bottom left", "Bottom center", "Bottom right"]
                    current: String(page.mh.position ?? "top-left")
                    onPicked: v => page.sys(["mango-set", "position", v])
                }
            }
            SRow {
                label: "Font size"
                SSlider {
                    from: 12; to: 40; step: 1
                    value: Number(page.mh.font_size ?? 24)
                    suffix: " px"
                    onMoved: v => page.sys(["mango-set", "font_size", String(Math.round(v))])
                }
            }
            Repeater {
                model: [
                    { key: "fps", label: "FPS counter" },
                    { key: "frametime", label: "Frame time graph", hint: "The line under the FPS." },
                    { key: "gpu_stats", label: "GPU load" },
                    { key: "cpu_stats", label: "CPU load" },
                    { key: "gpu_temp", label: "GPU temperature" },
                    { key: "ram", label: "RAM usage" },
                    { key: "vram", label: "VRAM usage" },
                ]
                SRow {
                    required property var modelData
                    label: modelData.label
                    hint: modelData.hint ?? ""
                    SToggle {
                        checked: page.mh[modelData.key] !== undefined && page.mh[modelData.key] !== "0"
                        onToggled: v => page.sys(["mango-set", modelData.key, v ? "on" : "off"])
                    }
                }
            }
            SRow {
                label: "Full MangoHud config"
                hint: "~/.config/MangoHud/MangoHud.conf — Shift+F12 toggles the overlay in game."
                SButton {
                    icon: "󰏫"; text: "Edit"
                    onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.config/MangoHud/MangoHud.conf"])
                }
            }

            SHeading { text: "INSTALLED" }
            SHint {
                width: parent.width
                leftPadding: 14; rightPadding: 14
                text: ["gamemoded", "mangohud", "gamescope", "steam", "lutris", "heroic", "vkbasalt"]
                    .map(t => (page.has(t) ? "󰄬 " : "✗ ") + t).join("    ")
            }
        }
    }
}
