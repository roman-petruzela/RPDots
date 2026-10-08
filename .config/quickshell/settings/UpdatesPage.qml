import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    readonly property var result: host.updatesCache
    readonly property bool checking: proc.running
    readonly property int total: result ? result.repo.length + result.aur.length + result.flatpak.length : 0

    property var dots: null

    function check() {
        proc.running = false
        proc.running = true
        checkDots()
    }
    function checkDots() {
        dotsProc.running = false
        dotsProc.running = true
    }

    Component.onCompleted: if (!host.updatesCache) check(); else checkDots()

    Process {
        id: dotsProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "dotfiles"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.dots = JSON.parse(text) } catch (e) { page.dots = null }
            }
        }
    }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "updates"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.host.updatesCache = JSON.parse(text) }
                catch (e) { page.host.showError("Update check failed") }
            }
        }
    }

    function run(title, cmd, term) {
        host.job.start(title, cmd, term, code => { if (code === 0) page.check(); else page.checkDots() })
    }

    readonly property var terminalAll: ["kitty", "--hold", "-e", "paru"]

    component Group: Column {
        id: grp
        property string title
        property string icon
        property var items: []
        property string actionText: ""
        signal action()
        width: parent ? parent.width : 0
        visible: items.length > 0
        spacing: 2

        Item {
            width: parent.width
            height: 44
            SHeading {
                anchors.verticalCenter: parent.verticalCenter
                topPadding: 0; bottomPadding: 0
                text: grp.title + "  ·  " + grp.items.length
            }
            SButton {
                visible: grp.actionText !== ""
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                icon: grp.icon; text: grp.actionText
                busy: page.host.job.running
                onClicked: grp.action()
            }
        }
        Repeater {
            model: grp.items
            Item {
                required property var modelData
                width: grp.width
                height: 30
                SLabel {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    width: parent.width * 0.45
                    text: modelData.name
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                SMono {
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    width: parent.width * 0.5
                    horizontalAlignment: Text.AlignRight
                    text: (modelData.old !== "" ? modelData.old + "  →  " : "") + modelData.new
                    elide: Text.ElideLeft
                }
            }
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
            spacing: 8
            topPadding: 8

            SCard {
                width: parent.width
                height: headCol.implicitHeight + 40

                Text {
                    id: bigIcon
                    anchors { left: parent.left; leftMargin: 24; top: parent.top; topMargin: 22 }
                    width: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: page.checking ? "󰔟" : page.total > 0 ? "󰚰" : "󰄬"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 34
                    color: page.total > 0 ? Colors.tertiary : Colors.accent2
                }
                Column {
                    id: headCol
                    anchors { left: bigIcon.right; leftMargin: 18; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        text: page.checking && !page.result ? "Checking for updates…"
                            : page.total === 0 ? "System is up to date"
                            : page.total + (page.total === 1 ? " update available" : " updates available")
                    }
                    SHint {
                        width: parent.width
                        text: page.checking ? "Syncing package databases…"
                            : page.result ? (page.result.error !== "" ? page.result.error : "Last checked at " + page.result.checked) : ""
                        color: page.result?.error ? Colors.errorColor : Colors.onSurfaceVariant
                    }
                    Item { width: 1; height: 8 }
                    Row {
                        id: actions
                        spacing: 8
                        SButton {
                            icon: "󰑓"; text: "Check"
                            busy: page.checking
                            onClicked: page.check()
                        }
                        SButton {
                            visible: (page.result?.repo.length ?? 0) + (page.result?.aur.length ?? 0)
                                     + (page.result?.flatpak.length ?? 0) > 0
                            icon: "󰚰"; text: "Update all"
                            busy: page.host.job.running
                            onClicked: page.run("Updating pacman, AUR and Flatpak", ["rp-sys", "upgrade-all"],
                                                ["kitty", "--hold", "-e", "bash", "-c", "paru -Syu && flatpak update"])
                        }
                        SButton {
                            icon: "󰆍"; text: "Terminal"
                            onClicked: Quickshell.execDetached(page.terminalAll)
                        }
                    }
                }
            }

            SHint {
                width: parent.width
                leftPadding: 14; rightPadding: 14
                text: "Update all runs paru -Syu (repositories and AUR) and then Flatpak, with the log below. "
                    + "Terminal opens paru with prompts."
            }

            Group {
                title: "RPDOTS"
                icon: "󰊢"
                items: (page.dots?.commits ?? []).map(c => ({ name: c.subject, old: "", new: c.hash + "  ·  " + c.when }))
                actionText: "Update RPDots"
                onAction: page.run("Updating RPDots", [page.dots.repo + "/install.sh", "update"],
                                   ["kitty", "--hold", "-e", page.dots.repo + "/install.sh", "update"])
            }
            SHint {
                width: parent.width
                leftPadding: 14; rightPadding: 14
                visible: text !== ""
                color: page.dots?.conflicts.length ? Colors.tertiary : Colors.onSurfaceVariant
                text: !page.dots ? ""
                    : page.dots.conflicts.length ? "RPDots: your edits conflict with the update. Compare and delete: "
                        + page.dots.conflicts.map(f => "~/" + f).join(", ")
                    : page.dots.error !== "" ? "RPDots: " + page.dots.error
                    : page.dots.behind === 0 ? "RPDots is up to date (" + page.dots.head + ")."
                    : "Update RPDots pulls the repository and updates your configs. Files you changed are merged; "
                        + "on a conflict the new version is saved next to yours as .new."
            }

            Group {
                title: "REPOSITORIES"
                items: page.result?.repo ?? []
            }
            Group {
                title: "AUR"
                icon: "󰣇"
                items: page.result?.aur ?? []
                actionText: "Update AUR"
                onAction: page.run("Updating AUR packages (paru -Sua)", ["rp-sys", "upgrade-aur"],
                                   ["kitty", "--hold", "-e", "paru", "-Sua"])
            }
            Group {
                title: "FLATPAK"
                icon: "󰏖"
                items: page.result?.flatpak ?? []
                actionText: "Update Flatpak"
                onAction: page.run("Updating Flatpak apps", ["rp-sys", "upgrade-flatpak"],
                                   ["kitty", "--hold", "-e", "flatpak", "update"])
            }
        }
    }
}
