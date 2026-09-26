import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Historie: zavřené notifikace (mako), schránka (cliphist, i s náhledy
// obrázků) a příkazy terminálu (zsh). Backend `rp-history`.
Item {
    id: page
    required property var host

    property string tab: "notifications"
    property var notifications: []
    property var clips: []
    property var commands: []
    property string query: ""
    property var thumbs: ({})         // id položky schránky → cesta k náhledu
    property bool confirmClear: false

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/rp-history"

    function reload() {
        notifProc.running = false; notifProc.running = true
        clipProc.running = false; clipProc.running = true
        shellProc.running = false; shellProc.running = true
    }

    function hist(args) {
        actProc.running = false
        actProc.command = [bin].concat(args)
        actProc.running = true
    }

    Component.onCompleted: reload()

    Process {
        id: notifProc
        command: [page.bin, "notifications"]
        stdout: StdioCollector { onStreamFinished: { try { page.notifications = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: clipProc
        command: [page.bin, "clipboard"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.clips = JSON.parse(text) } catch (e) { return }
                // Náhledy obrázků jeden po druhém (cliphist decode do cache)
                page.thumbQueue = page.clips.filter(c => c.image && !page.thumbs[c.id]).map(c => c.id).slice(0, 24)
                page.nextThumb()
            }
        }
    }
    Process {
        id: shellProc
        command: [page.bin, "shell"]
        stdout: StdioCollector { onStreamFinished: { try { page.commands = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: actProc
        onExited: page.reload()
    }

    property var thumbQueue: []
    function nextThumb() {
        if (thumbQueue.length === 0 || thumbProc.running) return
        thumbProc.cid = thumbQueue[0]
        thumbQueue = thumbQueue.slice(1)
        thumbProc.command = [bin, "clip-thumb", thumbProc.cid]
        thumbProc.running = true
    }
    Process {
        id: thumbProc
        property string cid: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const t = Object.assign({}, page.thumbs)
                t[thumbProc.cid] = "file://" + text.trim()
                page.thumbs = t
            }
        }
        onExited: page.nextThumb()
    }

    function ago(ts) {
        if (!ts) return ""
        const s = Math.floor(Date.now() / 1000) - ts
        if (s < 60) return "just now"
        if (s < 3600) return Math.floor(s / 60) + " min ago"
        if (s < 86400) return Math.floor(s / 3600) + " h ago"
        return Math.floor(s / 86400) + " d ago"
    }

    readonly property var shownNotifs: notifications.filter(n => match(n.app + " " + n.summary + " " + n.body))
    readonly property var shownClips: clips.filter(c => match(c.text))
    readonly property var shownCommands: commands.filter(c => match(c.command))
    function match(t) { const q = query.trim().toLowerCase(); return q === "" || t.toLowerCase().includes(q) }

    Column {
        id: toolbar
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8; rightMargin: 12 }
        Item {
            width: parent.width
            height: 34
            SSegmented {
                id: tabs
                anchors.verticalCenter: parent.verticalCenter
                options: ["notifications", "clipboard", "terminal"]
                labels: ["Notifications", "Clipboard", "Terminal"]
                current: page.tab
                onPicked: v => { page.tab = v; page.confirmClear = false }
            }
            STextBox {
                anchors { left: tabs.right; leftMargin: 10; right: clearBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                icon: "󰍉"
                placeholder: "Search history"
                commitOnBlur: false
                onEdited: v => page.query = v
            }
            SButton {
                id: clearBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                visible: page.tab !== "notifications"
                danger: page.confirmClear
                icon: "󰆴"
                text: page.confirmClear ? "Really clear?" : "Clear all"
                onClicked: {
                    if (!page.confirmClear) { page.confirmClear = true; return }
                    page.confirmClear = false
                    page.hist([page.tab === "clipboard" ? "clip-wipe" : "shell-clear"])
                }
            }
        }
    }

    // ── Notifikace
    SWheel { flick: notifList }
    ListView {
        id: notifList
        visible: page.tab === "notifications"
        anchors { left: parent.left; right: parent.right; top: toolbar.bottom; topMargin: 10; bottom: parent.bottom }
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}
        model: page.shownNotifs
        header: SHint {
            width: notifList.width
            leftPadding: 14; bottomPadding: 8
            text: "Notifications you dismissed since mako started (it keeps them in memory only)."
        }
        delegate: Rectangle {
            id: nr
            required property var modelData
            width: notifList.width - 12
            height: Math.max(58, nCol.implicitHeight + 20)
            radius: 12
            color: nrHover.hovered ? Qt.alpha(Colors.onSurface, 0.04) : Qt.alpha(Colors.surfaceContainerHigh, 0.35)
            border.width: nr.modelData.urgency === 2 ? 1 : 0
            border.color: Colors.errorColor
            HoverHandler { id: nrHover }

            IconImage {
                id: nIcon
                anchors { left: parent.left; leftMargin: 14; top: parent.top; topMargin: 14 }
                implicitSize: 28
                source: {
                    const i = nr.modelData.icon
                    if (i.startsWith("file://") || i.startsWith("/")) return i.startsWith("/") ? "file://" + i : i
                    return Quickshell.iconPath(i || nr.modelData.desktop || nr.modelData.app.toLowerCase(), true)
                        || Quickshell.iconPath("dialog-information")
                }
            }
            Column {
                id: nCol
                anchors { left: nIcon.right; leftMargin: 12; right: nButtons.left; rightMargin: 12; top: parent.top; topMargin: 10 }
                spacing: 2
                SHint { text: nr.modelData.app; wrapMode: Text.NoWrap }
                SLabel { width: parent.width; wrapMode: Text.Wrap; text: nr.modelData.summary; font.weight: Font.Medium }
                SHint { visible: text !== ""; width: parent.width; text: nr.modelData.body; maximumLineCount: 3; elide: Text.ElideRight }
            }
            Row {
                id: nButtons
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 6
                SButton {
                    flat: true
                    icon: "󰆏"; text: ""
                    onClicked: Quickshell.execDetached(["wl-copy", nr.modelData.summary + (nr.modelData.body ? "\n" + nr.modelData.body : "")])
                }
                // Znovu ukázat (nová notifikace se stejným obsahem)
                SButton {
                    flat: true
                    icon: "󰑐"; text: ""
                    onClicked: Quickshell.execDetached(["notify-send", "-a", nr.modelData.app, nr.modelData.summary, nr.modelData.body])
                }
            }
        }
        SHint {
            anchors.centerIn: parent
            visible: notifList.count === 0
            text: "No notifications."
        }
    }

    // ── Schránka
    SWheel { flick: clipList }
    ListView {
        id: clipList
        visible: page.tab === "clipboard"
        anchors { left: parent.left; right: parent.right; top: toolbar.bottom; topMargin: 10; bottom: parent.bottom }
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}
        model: page.shownClips
        header: SHint {
            width: clipList.width
            leftPadding: 14; bottomPadding: 8
            text: "Click an item to copy it again. Mod+Ctrl+V opens the quick picker."
        }
        delegate: Rectangle {
            id: cr
            required property var modelData
            width: clipList.width - 12
            height: modelData.image ? 84 : Math.min(76, Math.max(46, cText.implicitHeight + 20))
            radius: 12
            color: crHover.hovered ? Qt.alpha(Colors.primary, 0.1) : Qt.alpha(Colors.surfaceContainerHigh, 0.35)
            HoverHandler { id: crHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { page.hist(["clip-copy", cr.modelData.id]); page.host.showInfo("Copied to the clipboard") } }

            Image {
                id: thumb
                visible: cr.modelData.image
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 100; height: 64
                fillMode: Image.PreserveAspectFit
                source: page.thumbs[cr.modelData.id] ?? ""
                asynchronous: true
                sourceSize: Qt.size(200, 128)
            }
            SLabel {
                id: cText
                anchors {
                    left: cr.modelData.image ? thumb.right : parent.left; leftMargin: cr.modelData.image ? 14 : 14
                    right: cDel.left; rightMargin: 12; verticalCenter: parent.verticalCenter
                }
                text: cr.modelData.image ? "Image · " + cr.modelData.format.toUpperCase() + " " + cr.modelData.width + "×"
                                           + cr.modelData.height + " · " + cr.modelData.size
                                         : cr.modelData.text
                font.pixelSize: 12
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            SButton {
                id: cDel
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                flat: true; danger: true
                icon: "󰆴"; text: ""
                onClicked: page.hist(["clip-delete", cr.modelData.id])
            }
        }
        SHint { anchors.centerIn: parent; visible: clipList.count === 0; text: "Clipboard history is empty." }
    }

    // ── Terminál
    SWheel { flick: shellList }
    ListView {
        id: shellList
        visible: page.tab === "terminal"
        anchors { left: parent.left; right: parent.right; top: toolbar.bottom; topMargin: 10; bottom: parent.bottom }
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}
        model: page.shownCommands
        header: SHint {
            width: shellList.width
            leftPadding: 14; bottomPadding: 8
            text: "Last 400 distinct zsh commands. Click to copy; the bin deletes every occurrence from ~/.zsh_history."
        }
        delegate: Rectangle {
            id: sr
            required property var modelData
            width: shellList.width - 12
            height: Math.max(38, sText.implicitHeight + 16)
            radius: 10
            color: srHover.hovered ? Qt.alpha(Colors.primary, 0.1) : "transparent"
            HoverHandler { id: srHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Quickshell.execDetached(["wl-copy", sr.modelData.command]) }

            SMono {
                id: sText
                anchors { left: parent.left; leftMargin: 14; right: sTime.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: sr.modelData.command
                color: Colors.onSurface
                font.pixelSize: 12
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            SHint {
                id: sTime
                anchors { right: sDel.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                wrapMode: Text.NoWrap
                text: page.ago(sr.modelData.time)
            }
            SButton {
                id: sDel
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                flat: true; danger: true
                icon: "󰆴"; text: ""
                onClicked: page.hist(["shell-delete", sr.modelData.command])
            }
        }
        SHint { anchors.centerIn: parent; visible: shellList.count === 0; text: "No history." }
    }
}
