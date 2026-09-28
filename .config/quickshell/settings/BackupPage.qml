import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property var b: null
    property string desc: ""
    property string cfg: "root"
    property string importPath: ""

    Process {
        id: proc
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "backup"]
        stdout: StdioCollector { onStreamFinished: { try { page.b = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: exportProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "settings-export"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) page.host.showInfo("Saved " + text.trim()) }
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

            SCard {
                width: parent.width
                height: 92
                Text {
                    id: snapIcon
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    text: "󰁯"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 32
                    color: page.b?.snapper ? Colors.accent2 : Colors.onSurfaceVariant
                }
                Column {
                    anchors { left: snapIcon.right; leftMargin: 18; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel {
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        text: page.b?.snapper ? "Snapshots are set up" : "No snapshot tool"
                    }
                    SHint {
                        width: parent.width
                        text: page.b ? (page.b.fs + " · snapper configs: " + page.b.configs.map(c => c.name + " (" + c.subvolume + ")").join(", ")) : ""
                    }
                }
            }

            SHeading { text: "AUTOMATIC" }
            SRow {
                label: "Timeline snapshots"
                hint: "Hourly snapshots, thinned out over time (snapper-timeline.timer)."
                SLabel { text: page.b?.timeline ? "On" : "Off"; color: page.b?.timeline ? Colors.accent2 : Colors.outline; font.pixelSize: 12 }
            }
            SRow {
                label: "Before and after every update"
                hint: "snap-pac takes a pre/post pair around each pacman transaction."
                SLabel { text: page.b?.snapPac ? "On" : "Not installed"; color: page.b?.snapPac ? Colors.accent2 : Colors.outline; font.pixelSize: 12 }
            }
            SRow {
                label: "Cleanup"
                hint: "Old snapshots are removed by snapper-cleanup.timer."
                SLabel { text: page.b?.cleanup ? "On" : "Off"; color: page.b?.cleanup ? Colors.accent2 : Colors.outline; font.pixelSize: 12 }
            }

            SHeading { text: "MANUAL" }
            SRow {
                label: "Configuration"
                SSegmented {
                    options: (page.b?.configs ?? []).map(c => c.name)
                    current: page.cfg
                    onPicked: v => page.cfg = v
                }
            }
            SRow {
                label: "Take a snapshot now"
                hint: "Worth it before risky changes. Asks for your password."
                Row {
                    spacing: 8
                    STextBox {
                        width: 220
                        placeholder: "Description"
                        commitOnBlur: false
                        onEdited: v => page.desc = v
                    }
                    SButton {
                        icon: "󰄄"; text: "Create"
                        busy: page.desc.trim() === "" || page.host.job.running
                        onClicked: page.host.job.start("Snapshot of " + page.cfg + ": " + page.desc,
                            ["rp-sys", "snapshot", "create", page.cfg, page.desc.trim()], [])
                    }
                }
            }
            SRow {
                label: "List snapshots"
                hint: "Shows them in the log panel (snapper needs root to read them)."
                SButton {
                    icon: "󰋚"; text: "Show"
                    busy: page.host.job.running
                    onClicked: page.host.job.start("Snapshots of " + page.cfg, ["rp-sys", "snapshot", "list", page.cfg],
                        ["kitty", "--hold", "-e", "sudo", "snapper", "-c", page.cfg, "list"])
                }
            }
            SRow {
                label: "Restore"
                hint: "Roll back or compare with snapper, or boot an older snapshot from the boot menu. Deliberately not a button."
            }

            SHeading { text: "THIS WINDOW'S SETTINGS" }
            SRow {
                label: "Export"
                hint: "settings.json, displays.json and modules.conf into ~/rprice-settings-DATE.tar.gz."
                SButton { icon: "󰈝"; text: "Export"; onClicked: exportProc.running = true }
            }
            SRow {
                label: "Import"
                hint: "Path to an exported .tar.gz; applies it right away."
                Row {
                    spacing: 8
                    STextBox {
                        width: 260
                        placeholder: "~/rprice-settings-….tar.gz"
                        commitOnBlur: false
                        onEdited: v => page.importPath = v
                    }
                    SButton {
                        icon: "󰈞"; text: "Import"
                        busy: page.importPath.trim() === "" || page.host.job.running
                        onClicked: page.host.job.start("Importing settings", ["rp-sys", "settings-import",
                            page.importPath.trim().replace(/^~/, Quickshell.env("HOME"))], [], code => page.host.reload())
                    }
                }
            }
        }
    }
}
