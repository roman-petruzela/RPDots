import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property string tab: "installed"
    property var apps: []
    property var defaults: []
    property var autostart: []
    property string query: ""
    property bool showHidden: false
    property string expanded: ""
    property string owner: ""
    property bool adding: false

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/rp-apps"

    function reload() {
        listProc.running = false; listProc.running = true
        defProc.running = false; defProc.running = true
        autoProc.running = false; autoProc.running = true
    }

    function apps_(args) {
        actProc.running = false
        actProc.command = [bin].concat(args)
        actProc.running = true
    }

    function appIcon(name) {
        if (!name) return Quickshell.iconPath("application-x-executable")
        if (name.startsWith("/")) return "file://" + name
        return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable")
    }

    Component.onCompleted: reload()

    Process {
        id: listProc
        command: [page.bin, "list"]
        stdout: StdioCollector { onStreamFinished: { try { page.apps = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: defProc
        command: [page.bin, "defaults"]
        stdout: StdioCollector { onStreamFinished: { try { page.defaults = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: autoProc
        command: [page.bin, "autostart"]
        stdout: StdioCollector { onStreamFinished: { try { page.autostart = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: actProc
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") page.host.showError(text.trim().replace(/^rp-apps: /, "")) }
        onExited: page.reload()
    }
    Process {
        id: ownerProc
        stdout: StdioCollector { onStreamFinished: page.owner = text.trim() }
    }

    function toggleDetails(a) {
        if (expanded === a.id) { expanded = ""; return }
        expanded = a.id
        owner = ""
        if (a.flatpak) { owner = a.id.replace(/\.desktop$/, ""); return }
        ownerProc.running = false
        ownerProc.command = ["pacman", "-Qqo", a.path]
        ownerProc.running = true
    }

    readonly property var shownApps: {
        const q = query.trim().toLowerCase()
        return apps.filter(a => (showHidden || !a.hidden)
            && (q === "" || (a.name + " " + a.comment + " " + a.id).toLowerCase().includes(q)))
    }

    Column {
        id: toolbar
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8; rightMargin: 12 }
        spacing: 10
        Item {
            width: parent.width
            height: 34
            SSegmented {
                id: tabs
                anchors.verticalCenter: parent.verticalCenter
                options: ["installed", "defaults", "startup"]
                labels: ["Installed", "Default apps", "Startup"]
                current: page.tab
                onPicked: v => page.tab = v
            }
            STextBox {
                visible: page.tab === "installed" || page.adding
                anchors { left: tabs.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
                icon: "󰍉"
                placeholder: page.adding ? "Pick an app to start at login" : "Search apps"
                commitOnBlur: false
                onEdited: v => page.query = v
            }
        }
    }

    SWheel { flick: appList }
    ListView {
        id: appList
        visible: page.tab === "installed" || page.adding
        anchors { left: parent.left; right: parent.right; top: toolbar.bottom; topMargin: 10; bottom: appFooter.top }
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}
        model: page.shownApps

        delegate: Rectangle {
            id: ar
            required property var modelData
            readonly property bool open: page.expanded === modelData.id && !page.adding
            width: appList.width - 12
            height: 50 + (open ? detail.implicitHeight + 12 : 0)
            radius: 12
            color: open ? Qt.alpha(Colors.surfaceContainerHigh, 0.6) : arHover.hovered ? Qt.alpha(Colors.onSurface, 0.04) : "transparent"
            HoverHandler { id: arHover }

            Item {
                id: head
                width: parent.width
                height: 50
                IconImage {
                    id: ic
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    implicitSize: 28
                    source: page.appIcon(ar.modelData.icon)
                    opacity: ar.modelData.hidden ? 0.45 : 1
                }
                Column {
                    anchors { left: ic.right; leftMargin: 12; right: arRight.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    SLabel { width: parent.width; elide: Text.ElideRight; text: ar.modelData.name; color: ar.modelData.hidden ? Colors.outline : Colors.onSurface }
                    SHint { width: parent.width; wrapMode: Text.NoWrap; elide: Text.ElideRight; text: ar.modelData.comment || ar.modelData.id }
                }
                Row {
                    id: arRight
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Rectangle {
                        visible: ar.modelData.flatpak || ar.modelData.hidden
                        anchors.verticalCenter: parent.verticalCenter
                        width: tagT.implicitWidth + 14; height: 20; radius: 10
                        color: Qt.alpha(Colors.accent2, 0.14)
                        Text {
                            id: tagT
                            anchors.centerIn: parent
                            text: ar.modelData.hidden ? "hidden" : "flatpak"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                            color: Colors.accent2
                        }
                    }
                    SButton {
                        visible: page.adding
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰐕"; text: "Add"
                        onClicked: { page.apps_(["autostart-add", ar.modelData.id]); page.adding = false; page.tab = "startup" }
                    }
                    SButton {
                        visible: !page.adding
                        anchors.verticalCenter: parent.verticalCenter
                        flat: true
                        icon: "󰐊"; text: ""
                        onClicked: Quickshell.execDetached(["gtk-launch", ar.modelData.id])
                    }
                }
                MouseArea {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: arRight.left }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!page.adding) page.toggleDetails(ar.modelData)
                }
            }

            Column {
                id: detail
                visible: ar.open
                anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 54; rightMargin: 14 }
                spacing: 8
                SMono { width: parent.width; wrapMode: Text.WrapAnywhere; text: ar.modelData.exec }
                SHint { width: parent.width; text: ar.modelData.path + (page.owner ? "  ·  package " + page.owner : "") }
                Row {
                    spacing: 8
                    SButton {
                        icon: ar.modelData.hidden ? "󰈈" : "󰈉"
                        text: ar.modelData.hidden ? "Show in launcher" : "Hide from launcher"
                        onClicked: page.apps_(["hide", ar.modelData.id, ar.modelData.hidden ? "off" : "on"])
                    }
                    SButton {
                        visible: page.owner !== ""
                        danger: true
                        icon: "󰆴"; text: "Uninstall"
                        busy: page.host.job.running
                        onClicked: page.host.job.start("Uninstalling " + page.owner, ["rp-sys", "remove", page.owner],
                            ["kitty", "--hold", "-e", "sudo", "pacman", "-Rns", page.owner], code => page.reload())
                    }
                }
            }
        }
    }
    Item {
        id: appFooter
        visible: appList.visible
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; rightMargin: 12 }
        height: appList.visible ? 44 : 0
        SHint {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: page.shownApps.length + " apps"
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 10
            SButton { visible: page.adding; icon: "󰅖"; text: "Cancel"; onClicked: { page.adding = false; page.tab = "startup" } }
            SHint { visible: !page.adding; anchors.verticalCenter: parent.verticalCenter; text: "Show hidden"; wrapMode: Text.NoWrap }
            SToggle { visible: !page.adding; anchors.verticalCenter: parent.verticalCenter; checked: page.showHidden; onToggled: v => page.showHidden = v }
        }
    }

    SWheel { flick: flick }
    Flickable {
        id: flick
        visible: !appList.visible
        anchors { left: parent.left; right: parent.right; top: toolbar.bottom; topMargin: 6; bottom: parent.bottom }
        contentHeight: col.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}

        Column {
            id: col
            width: flick.width - 12
            spacing: 2

            Column {
                visible: page.tab === "defaults"
                width: parent.width
                spacing: 2
                SHeading { text: "OPEN WITH" }
                Repeater {
                    model: page.defaults
                    SRow {
                        required property var modelData
                        label: modelData.label
                        hint: modelData.mimes.join(", ")
                        SDropdown {
                            width: 260
                            options: modelData.candidates.map(c => c.id)
                            labels: modelData.candidates.map(c => c.name)
                            current: modelData.current
                            displayText: modelData.currentName || "Not set"
                            onPicked: v => page.apps_(["set-default", modelData.id, v])
                        }
                    }
                }
                SHint {
                    width: parent.width
                    leftPadding: 14; rightPadding: 14; topPadding: 10
                    text: "Saved in ~/.config/mimeapps.list. Only apps that declare they can open that type are listed."
                }
            }

            Column {
                visible: page.tab === "startup" && !page.adding
                width: parent.width
                spacing: 2
                Item {
                    width: parent.width
                    height: 50
                    SHeading { anchors.verticalCenter: parent.verticalCenter; topPadding: 0; bottomPadding: 0; text: "START AT LOGIN" }
                    SButton {
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        icon: "󰐕"; text: "Add app"
                        onClicked: { page.adding = true; page.query = "" }
                    }
                }
                Repeater {
                    model: page.autostart.filter(a => a.here)
                    SRow {
                        required property var modelData
                        label: modelData.name
                        hint: (modelData.state === "running" ? "running now · " : "") + modelData.exec
                        Row {
                            spacing: 8
                            SButton {
                                visible: modelData.user && !modelData.system
                                anchors.verticalCenter: parent.verticalCenter
                                flat: true; danger: true
                                icon: "󰆴"; text: ""
                                onClicked: page.apps_(["autostart-remove", modelData.file])
                            }
                            SToggle {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: modelData.enabled
                                onToggled: v => page.apps_(["autostart-set", modelData.file, v ? "on" : "off"])
                            }
                        }
                    }
                }
                SHeading { text: "RICE SERVICES" }
                SHint {
                    width: parent.width
                    leftPadding: 14; rightPadding: 14; bottomPadding: 6
                    text: "Started by niri (start-rice-services.sh) and systemd user units: quickshell, swayidle, kanshi, "
                        + "nm-applet, blueman-applet, the audio sync daemon and the wallpaper. Edit those in the dotfiles."
                }
                SHeading {
                    visible: page.autostart.some(a => !a.here)
                    text: "FOR OTHER DESKTOPS  ·  " + page.autostart.filter(a => !a.here).length
                }
                SHint {
                    visible: page.autostart.some(a => !a.here)
                    width: parent.width
                    leftPadding: 14; rightPadding: 14
                    text: page.autostart.filter(a => !a.here).map(a => a.name).join(", ") + " — only start in GNOME/Xfce/…, not in niri."
                }
            }
        }
    }
}
