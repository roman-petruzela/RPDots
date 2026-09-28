import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property string mode: "installed"
    property var packages: []
    property bool loading: false
    property string query: ""
    property string filter: "explicit"
    property string sort: "name"
    property string expanded: ""
    property var details: []
    property string confirmRemove: ""
    property bool confirmOrphans: false
    property var searchResults: []
    property bool searching: false

    readonly property var counts: ({
        all: packages.length,
        explicit: packages.filter(p => p.reason === "explicit" && p.source === "pacman").length,
        aur: packages.filter(p => p.aur).length,
        flatpak: packages.filter(p => p.source === "flatpak").length,
        orphans: packages.filter(p => p.orphan).length,
    })

    readonly property var shown: {
        const q = query.trim().toLowerCase()
        let list = packages.filter(p =>
            filter === "all" ? true
            : filter === "explicit" ? p.reason === "explicit" && p.source === "pacman"
            : filter === "aur" ? p.aur
            : filter === "flatpak" ? p.source === "flatpak"
            : p.orphan)
        if (q !== "") list = list.filter(p => p.name.toLowerCase().includes(q) || p.description.toLowerCase().includes(q))
        const byDate = p => p.date ? Date.parse(p.date) || 0 : 0
        return list.slice().sort(sort === "size" ? (a, b) => b.size - a.size
            : sort === "date" ? (a, b) => byDate(b) - byDate(a)
            : (a, b) => a.name.localeCompare(b.name))
    }

    function reload() {
        loading = true
        listProc.running = false
        listProc.running = true
    }

    function toggleDetails(name) {
        confirmRemove = ""
        if (expanded === name) { expanded = ""; return }
        expanded = name
        details = []
        infoProc.running = false
        infoProc.command = [Quickshell.env("HOME") + "/.local/bin/rp-sys", "pkginfo", name]
        infoProc.running = true
    }

    function doSearch() {
        if (query.trim().length < 2) return
        searching = true
        searchProc.running = false
        searchProc.command = [Quickshell.env("HOME") + "/.local/bin/rp-sys", "search", query.trim()]
        searchProc.running = true
    }

    function remove(name) {
        if (confirmRemove !== name) { confirmRemove = name; return }
        confirmRemove = ""
        host.job.start("Removing " + name, ["rp-sys", "remove", name],
                       ["kitty", "--hold", "-e", "sudo", "pacman", "-Rns", name],
                       code => { if (code === 0) { page.expanded = ""; page.reload() } })
    }

    function install(name) {
        host.job.start("Installing " + name, ["rp-sys", "install", name],
                       ["kitty", "--hold", "-e", "paru", "-S", name],
                       code => { if (code === 0) { page.reload(); page.doSearch() } })
    }

    function human(b) {
        if (b <= 0) return ""
        const u = ["B", "KiB", "MiB", "GiB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return b.toFixed(i === 0 ? 0 : 1) + " " + u[i]
    }

    Component.onCompleted: reload()

    Process {
        id: listProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "packages"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.loading = false
                try { page.packages = JSON.parse(text) } catch (e) { page.host.showError("Could not list packages") }
            }
        }
    }
    Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: { try { page.details = JSON.parse(text) } catch (e) { page.details = [] } }
        }
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.searching = false
                try { page.searchResults = JSON.parse(text) } catch (e) { page.searchResults = [] }
            }
        }
    }

    Column {
        id: toolbar
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8; rightMargin: 12 }
        spacing: 10

        Item {
            width: parent.width
            height: 34
            SSegmented {
                id: modeSwitch
                anchors.verticalCenter: parent.verticalCenter
                options: ["installed", "browse"]
                labels: ["Installed", "Browse & install"]
                current: page.mode
                onPicked: v => { page.mode = v; page.expanded = "" }
            }
            STextBox {
                anchors { left: modeSwitch.right; leftMargin: 10; right: sideButtons.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                icon: "󰍉"
                commitOnBlur: false
                placeholder: page.mode === "installed" ? "Filter installed packages" : "Search repositories and AUR, Enter to search"
                onEdited: v => page.query = v
                onCommitted: v => { page.query = v; if (page.mode === "browse") page.doSearch() }
            }
            Row {
                id: sideButtons
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                SSpinner { anchors.verticalCenter: parent.verticalCenter; running: page.loading || page.searching }
                SButton { icon: "󰑓"; text: ""; onClicked: page.reload() }
            }
        }

        Item {
            visible: page.mode === "installed"
            width: parent.width
            height: 30
            Row {
                spacing: 8
                Repeater {
                    model: [
                        { id: "explicit", label: "Explicit" }, { id: "aur", label: "AUR" },
                        { id: "flatpak", label: "Flatpak" }, { id: "orphans", label: "Orphans" },
                        { id: "all", label: "All" },
                    ]
                    SChip {
                        required property var modelData
                        text: modelData.label
                        count: page.counts[modelData.id]
                        selected: page.filter === modelData.id
                        onClicked: { page.filter = modelData.id; page.confirmOrphans = false }
                    }
                }
            }
            SDropdown {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 150
                height: 30
                options: ["name", "size", "date"]
                labels: ["Sort: name", "Sort: size", "Sort: recent"]
                current: page.sort
                onPicked: v => page.sort = v
            }
        }
    }

    Item {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; rightMargin: 12 }
        height: page.mode === "installed" ? 48 : 0
        visible: page.mode === "installed"
        SHint {
            anchors { left: parent.left; leftMargin: 14; right: footerButtons.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            color: page.confirmOrphans ? Colors.tertiary : Colors.onSurfaceVariant
            text: page.confirmOrphans
                ? "These go. Open one and press Keep if you use it directly."
                : page.shown.length + " shown · " + page.human(page.shown.reduce((a, p) => a + p.size, 0))
        }
        Row {
            id: footerButtons
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            SButton {
                visible: page.counts.orphans > 0
                danger: page.confirmOrphans
                icon: "󰆴"
                text: page.confirmOrphans ? "Really remove all " + page.counts.orphans + "?"
                                          : "Remove orphans (" + page.counts.orphans + ")"
                busy: page.host.job.running
                onClicked: {
                    if (!page.confirmOrphans) {
                        page.filter = "orphans"
                        page.confirmOrphans = true
                        return
                    }
                    page.confirmOrphans = false
                    page.host.job.start("Removing orphaned packages", ["rp-sys", "remove-orphans"],
                        ["kitty", "--hold", "-e", "sh", "-c", "sudo pacman -Rns $(pacman -Qdtq)"], code => page.reload())
                }
            }
            SButton {
                icon: "󰃢"; text: "Clean cache"
                busy: page.host.job.running
                onClicked: page.host.job.start("Cleaning package cache", ["rp-sys", "clean-cache"],
                    ["kitty", "--hold", "-e", "sudo", "pacman", "-Sc"])
            }
        }
    }

    SWheel { flick: list }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: toolbar.bottom; topMargin: 10; bottom: footer.top }
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}
        model: page.mode === "installed" ? page.shown : page.searchResults
        reuseItems: true

        delegate: Rectangle {
            id: pkgRow
            required property var modelData
            required property int index
            readonly property bool open: page.expanded === modelData.name
            readonly property bool installedMode: page.mode === "installed"

            width: list.width - 12
            height: head.height + (open ? detailCol.implicitHeight + 16 : 0)
            radius: 12
            color: open ? Qt.alpha(Colors.surfaceContainerHigh, 0.6)
                : rowHover.hovered ? Qt.alpha(Colors.onSurface, 0.04) : "transparent"
            HoverHandler { id: rowHover }

            Item {
                id: head
                width: parent.width
                height: 50

                Column {
                    anchors { left: parent.left; leftMargin: 14; right: meta.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Row {
                        spacing: 8
                        height: nameText.implicitHeight
                        SLabel { id: nameText; text: pkgRow.modelData.name; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        SMono { text: pkgRow.modelData.version; anchors.verticalCenter: parent.verticalCenter }
                    }
                    SHint {
                        width: parent.width
                        text: pkgRow.modelData.description
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                    }
                }

                Row {
                    id: meta
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    Repeater {
                        model: {
                            const p = pkgRow.modelData
                            if (!pkgRow.installedMode) return [p.source === "aur" ? "AUR" : p.repo].concat(p.installed ? ["installed"] : [])
                            const t = []
                            if (p.aur) t.push("AUR")
                            if (p.source === "flatpak") t.push("flatpak")
                            if (p.orphan) t.push("orphan")
                            else if (p.reason === "dependency") t.push("dependency")
                            return t
                        }
                        Rectangle {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: tagText.implicitWidth + 14
                            height: 20
                            radius: 10
                            color: Qt.alpha(modelData === "orphan" ? Colors.tertiary : Colors.accent2, 0.14)
                            Text {
                                id: tagText
                                anchors.centerIn: parent
                                text: modelData
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: modelData === "orphan" ? Colors.tertiary : Colors.accent2
                            }
                        }
                    }
                    SHint {
                        visible: pkgRow.installedMode
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.NoWrap
                        text: page.human(pkgRow.modelData.size ?? 0)
                    }
                    SButton {
                        visible: !pkgRow.installedMode && !pkgRow.modelData.installed
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰇚"; text: "Install"
                        busy: page.host.job.running
                        onClicked: page.install(pkgRow.modelData.name)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pkgRow.open ? "󰅃" : "󰅀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: Colors.onSurfaceVariant
                    }
                }

                MouseArea {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: meta.left }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.toggleDetails(pkgRow.modelData.name)
                }
                TapHandler {
                    onTapped: eventPoint => { if (eventPoint.position.x > head.width - 40) page.toggleDetails(pkgRow.modelData.name) }
                }
            }

            Column {
                id: detailCol
                visible: pkgRow.open
                anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 14; rightMargin: 14 }
                spacing: 4

                SHint { visible: page.details.length === 0; text: "Loading…" }
                Repeater {
                    model: {
                        const want = ["Description", "Version", "Repository", "Installed From", "URL", "Licenses",
                                      "Installed Size", "Install Date", "Install Reason", "Depends On",
                                      "Required By", "Optional For", "Packager", "Build Date", "Maintainer", "Votes"]
                        return want.map(k => page.details.find(d => d.key === k)).filter(d => d && d.value !== "None")
                    }
                    Item {
                        required property var modelData
                        width: detailCol.width
                        height: Math.max(22, val.implicitHeight + 4)
                        SHint {
                            id: key
                            width: 130
                            wrapMode: Text.NoWrap
                            text: parent.modelData.key
                        }
                        SLabel {
                            id: val
                            anchors { left: key.right; right: parent.right }
                            text: parent.modelData.value
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }
                Row {
                    visible: pkgRow.installedMode
                    topPadding: 6
                    spacing: 8
                    SButton {
                        danger: true
                        icon: "󰆴"
                        text: page.confirmRemove === pkgRow.modelData.name ? "Really remove?" : "Remove"
                        busy: page.host.job.running
                        onClicked: page.remove(pkgRow.modelData.name)
                    }
                    SButton {
                        visible: pkgRow.modelData.orphan || pkgRow.modelData.reason === "dependency"
                        icon: "󰐃"; text: "Keep"
                        busy: page.host.job.running
                        onClicked: page.host.job.start("Marking " + pkgRow.modelData.name + " as explicitly installed",
                            ["rp-sys", "keep", pkgRow.modelData.name],
                            ["kitty", "--hold", "-e", "sudo", "pacman", "-D", "--asexplicit", pkgRow.modelData.name],
                            code => { if (code === 0) page.reload() })
                    }
                    SHint {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: page.confirmRemove === pkgRow.modelData.name
                        text: "Removes it with unneeded dependencies (pacman -Rns)."
                    }
                }
            }
        }

        SHint {
            anchors.centerIn: parent
            visible: list.count === 0 && !page.loading && !page.searching
            text: page.mode === "browse"
                ? (page.query.trim().length < 2 ? "Type a name and press Enter." : "Nothing found.")
                : "No packages match."
        }
    }
}
