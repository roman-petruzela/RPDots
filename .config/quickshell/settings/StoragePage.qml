import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property var st: null
    property var home: []
    property bool homeLoading: false
    property string confirm: ""

    function reload() {
        stProc.running = false; stProc.running = true
    }
    function loadHome() {
        homeLoading = true
        homeProc.running = false; homeProc.running = true
    }
    function clean(args, title) {
        if (confirm !== args.join(" ")) { confirm = args.join(" "); return }
        confirm = ""
        host.job.start(title, ["rp-sys", "clean"].concat(args), [], code => page.reload())
    }

    Component.onCompleted: reload()

    Process {
        id: stProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "storage"]
        stdout: StdioCollector { onStreamFinished: { try { page.st = JSON.parse(text) } catch (e) { page.host.showError("rp-sys storage failed") } } }
    }
    Process {
        id: homeProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "storage-home"]
        stdout: StdioCollector { onStreamFinished: { page.homeLoading = false; try { page.home = JSON.parse(text) } catch (e) {} } }
    }

    function human(b) {
        if (!b || b <= 0) return "—"
        const u = ["B", "KiB", "MiB", "GiB", "TiB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return b.toFixed(i < 2 ? 0 : 1) + " " + u[i]
    }

    readonly property real reclaimable: st ? st.items.reduce((a, i) => a + i.size, 0) : 0

    component CleanRow: SRow {
        id: crow
        property string what
        property string arg: ""
        property real size: 0
        property bool needsRoot: false
        readonly property string cmdKey: arg !== "" ? what + " " + arg : what
        SButton {
            danger: page.confirm === crow.cmdKey
            icon: crow.needsRoot ? "󰌾" : "󰃢"
            text: page.confirm === crow.cmdKey ? "Really clean?" : (crow.size > 0 ? "Clean " + page.human(crow.size) : "Clean")
            busy: page.host.job.running
            onClicked: page.clean(crow.arg !== "" ? [crow.what, crow.arg] : [crow.what], "Cleaning " + crow.label)
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

            Repeater {
                model: page.st?.disks ?? []
                SCard {
                    required property var modelData
                    width: col.width
                    height: 86
                    Column {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 20 }
                        spacing: 10
                        Item {
                            width: parent.width
                            height: 20
                            SLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰋊  " + modelData.mount + "   " + modelData.device
                                font.weight: Font.Medium
                            }
                            SHint {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                wrapMode: Text.NoWrap
                                text: page.human(modelData.free) + " free of " + page.human(modelData.size)
                            }
                        }
                        Rectangle {
                            width: parent.width; height: 8; radius: 4
                            color: Colors.surfaceContainerHighest
                            Rectangle {
                                readonly property real f: modelData.used / Math.max(modelData.size, 1)
                                width: parent.width * f; height: parent.height; radius: 4
                                color: f > 0.9 ? Colors.errorColor : Colors.primary
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: 6 }

            SHeading { text: "CLEAN UP  ·  " + page.human(page.reclaimable) + " RECLAIMABLE" }
            Repeater {
                model: (page.st?.items ?? []).filter(i => i.id !== "cache")
                CleanRow {
                    required property var modelData
                    label: modelData.label
                    hint: modelData.detail + (modelData.root ? " · asks for your password" : "")
                    what: modelData.id
                    size: modelData.size
                    needsRoot: modelData.root
                }
            }

            SHeading { text: "APP CACHES  ·  " + page.human((page.st?.items ?? []).find(i => i.id === "cache")?.size ?? 0) }
            SHint {
                width: parent.width
                leftPadding: 14; rightPadding: 14; bottomPadding: 6
                text: "Apps rebuild these, but some hold things worth keeping (Spotify's offline songs, paru's built packages)."
            }
            Repeater {
                model: page.st?.caches ?? []
                CleanRow {
                    required property var modelData
                    label: modelData.name
                    hint: modelData.path
                    what: "cache-dir"
                    arg: modelData.name
                    size: modelData.size
                }
            }

            Item {
                width: parent.width
                height: 50
                SHeading { anchors.verticalCenter: parent.verticalCenter; topPadding: 0; bottomPadding: 0; text: "LARGEST IN YOUR HOME FOLDER" }
                Row {
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    SSpinner { anchors.verticalCenter: parent.verticalCenter; running: page.homeLoading }
                    SButton { icon: "󰍉"; text: page.home.length ? "Rescan" : "Scan"; busy: page.homeLoading; onClicked: page.loadHome() }
                }
            }
            Repeater {
                model: page.home
                Item {
                    required property var modelData
                    width: col.width
                    height: 34
                    readonly property real f: modelData.size / Math.max(page.home[0]?.size ?? 1, 1)
                    SLabel {
                        id: hn
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        width: 200
                        elide: Text.ElideRight
                        text: modelData.name
                        font.pixelSize: 12
                    }
                    Rectangle {
                        anchors { left: hn.right; leftMargin: 12; right: hs.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        height: 6; radius: 3
                        color: Colors.surfaceContainerHighest
                        Rectangle { width: parent.width * f; height: parent.height; radius: 3; color: Qt.alpha(Colors.primary, 0.7) }
                    }
                    SHint {
                        id: hs
                        anchors { right: openBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 80
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.NoWrap
                        text: page.human(modelData.size)
                    }
                    SButton {
                        id: openBtn
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        flat: true
                        icon: "󰉋"; text: ""
                        onClicked: Quickshell.execDetached(["xdg-open", modelData.path])
                    }
                }
            }

            SHeading { text: "DISK HEALTH" }
            SRow {
                label: "SMART status"
                hint: "Health, wear and temperature of every disk (smartctl, asks for your password)."
                SButton {
                    icon: "󰓅"; text: "Check"
                    busy: page.host.job.running
                    onClicked: page.host.job.start("Disk health (SMART)", ["rp-sys", "clean", "smart"], [])
                }
            }
        }
    }
}
