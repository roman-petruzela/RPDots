import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Soukromí: kdo právě používá mikrofon, kameru a sdílení obrazovky (obnovuje
// se každé 3 s), a úklid stop — nedávné soubory, náhledy, historie launcheru.
// Historie schránky a terminálu je na stránce History.
Item {
    id: page
    required property var host

    property var pv: null
    property string confirm: ""

    function reload() { proc.running = false; proc.running = true }
    Component.onCompleted: reload()
    Timer { interval: 3000; running: true; repeat: true; onTriggered: page.reload() }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "privacy"]
        stdout: StdioCollector { onStreamFinished: { try { page.pv = JSON.parse(text) } catch (e) {} } }
    }
    Process { id: clearProc; onExited: page.reload() }

    function clear(what) {
        if (confirm !== what) { confirm = what; return }
        confirm = ""
        clearProc.command = [Quickshell.env("HOME") + "/.local/bin/rp-sys", "privacy-clear", what]
        clearProc.running = true
        host.showInfo("Cleared")
    }

    function human(b) {
        if (!b) return "empty"
        const u = ["B", "KiB", "MiB", "GiB"]; let i = 0
        while (b >= 1024 && i < 3) { b /= 1024; i++ }
        return b.toFixed(i < 2 ? 0 : 1) + " " + u[i]
    }

    // Stav jednoho zařízení (mikrofon/kamera/obrazovka)
    component UseRow: SRow {
        id: ur
        property var users: []
        SLabel {
            text: ur.users.length ? ur.users.join(", ") : "Not in use"
            color: ur.users.length ? Colors.tertiary : Colors.outline
            font.pixelSize: 12
        }
    }

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

            SHeading { text: "IN USE RIGHT NOW" }
            UseRow { icon: "󰍬"; label: "Microphone"; hint: "Apps recording from an input."; users: page.pv?.microphone ?? [] }
            UseRow { icon: "󰄀"; label: "Camera"; hint: "Processes holding a /dev/video device."; users: page.pv?.camera ?? [] }
            UseRow { icon: "󰍹"; label: "Screen sharing"; hint: "Screen or window captures through the portal."; users: page.pv?.screen ?? [] }
            SRow {
                label: "Microphone per app"
                hint: "Move or mute an app's microphone on the Sound page."
                SButton { icon: "󰁔"; text: "Sound"; onClicked: page.host.goTo("sound") }
            }

            SHeading { text: "TRACES" }
            SRow {
                label: "Recently used files"
                hint: (page.pv?.recentFiles ?? 0) + " entries that GTK apps show under Recent."
                SButton {
                    danger: page.confirm === "recent"
                    icon: "󰆴"; text: page.confirm === "recent" ? "Really clear?" : "Clear"
                    onClicked: page.clear("recent")
                }
            }
            SRow {
                label: "Thumbnail cache"
                hint: "Previews of images and videos you've browsed · " + page.human(page.pv?.thumbnails ?? 0)
                SButton {
                    danger: page.confirm === "thumbs"
                    icon: "󰆴"; text: page.confirm === "thumbs" ? "Really clear?" : "Clear"
                    onClicked: page.clear("thumbs")
                }
            }
            SRow {
                label: "Launcher history"
                hint: (page.pv?.launcherRecent ?? 0) + " recently launched apps shown first in Mod+D."
                SButton {
                    danger: page.confirm === "launcher"
                    icon: "󰆴"; text: page.confirm === "launcher" ? "Really clear?" : "Clear"
                    onClicked: page.clear("launcher")
                }
            }
            SRow {
                label: "Clipboard, notifications, terminal"
                hint: "On the History page."
                SButton { icon: "󰁔"; text: "History"; onClicked: page.host.goTo("history") }
            }
        }
    }
}
