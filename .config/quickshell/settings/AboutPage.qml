import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Item {
    id: page
    required property var host

    property var info: null
    property bool loading: false

    function reload() {
        loading = true
        proc.running = false
        proc.running = true
    }

    Component.onCompleted: {
        try { info = JSON.parse(cache.text()) } catch (e) {}
        reload()
    }

    FileView {
        id: cache
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/niri-rice/sysinfo.json"
        blockLoading: true
        printErrors: false
    }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.loading = false
                try { page.info = JSON.parse(text) } catch (e) { page.host.showError("rp-sys info failed") }
            }
        }
    }

    function gib(b) { return (b / 1073741824).toFixed(1) + " GiB" }

    function summary() {
        const i = info
        if (!i) return ""
        const out = [
            i.host + " — " + i.machine,
            "OS: " + i.os + ", kernel " + i.kernel,
            "CPU: " + i.cpu + " (" + i.cores + " threads)",
        ]
        for (const g of i.gpu) out.push("GPU: " + g)
        out.push("Memory: " + gib(i.memory.used) + " / " + gib(i.memory.total))
        for (const d of i.disks) out.push("Disk " + d.mount + ": " + gib(d.used) + " / " + gib(d.size) + " (" + d.fs + ")")
        for (const o of i.outputs) out.push("Display " + o.name + ": " + o.model + ", " + o.mode)
        out.push("niri " + i.niri + ", quickshell " + i.quickshell + ", " + i.shell)
        out.push("Packages: " + i.packages.pacman + " pacman (" + i.packages.aur + " AUR), " + i.packages.flatpak + " flatpak")
        out.push("Uptime: " + i.uptime)
        return out.join("\n")
    }

    component Field: Item {
        property string label
        property string value
        width: parent ? parent.width : 0
        height: Math.max(26, valueText.implicitHeight + 8)
        SHint {
            id: keyText
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 110
            text: parent.label
            wrapMode: Text.NoWrap
        }
        SLabel {
            id: valueText
            anchors { left: keyText.right; right: parent.right; verticalCenter: parent.verticalCenter }
            text: parent.value
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }

    component Usage: Column {
        property string label
        property real used: 0
        property real total: 1
        property string detail: ""
        width: parent ? parent.width : 0
        spacing: 6
        Item {
            width: parent.width
            height: 18
            SLabel { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.label; font.pixelSize: 12 }
            SHint {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: parent.parent.detail
                wrapMode: Text.NoWrap
            }
        }
        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Colors.surfaceContainerHighest
            Rectangle {
                readonly property real f: Math.min(1, parent.parent.used / Math.max(parent.parent.total, 1))
                width: parent.width * f
                height: parent.height
                radius: 3
                color: f > 0.9 ? Colors.errorColor : Colors.accent2
            }
        }
    }

    component Card: SCard {
        id: card
        property string title
        property string icon
        default property alias content: cardCol.data
        height: cardCol.implicitHeight + 66
        readonly property int inset: 18
        Item {
            id: cardHead
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: card.inset }
            height: card.inset
            Text {
                id: cardIcon
                width: card.inset; height: card.inset
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: card.icon
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pixelSize: 16
                color: Colors.accent2
            }
            SLabel {
                id: cardTitle
                anchors { left: cardIcon.right; leftMargin: card.inset; verticalCenter: cardIcon.verticalCenter }
                text: card.title
                font.weight: Font.DemiBold
            }
        }
        Column {
            id: cardCol
            anchors { left: parent.left; right: parent.right; top: cardHead.bottom; margins: 18; topMargin: 12 }
            spacing: 8
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
            spacing: 14
            topPadding: 8

            SCard {
                width: parent.width
                height: 108

                Text {
                    id: logo
                    anchors { left: parent.left; leftMargin: 26; verticalCenter: parent.verticalCenter }
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 52
                    color: Colors.primary
                }
                Column {
                    anchors { left: logo.right; leftMargin: 24; right: headButtons.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel {
                        text: page.info ? page.info.host : "…"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    SHint { text: page.info ? page.info.machine : ""; width: parent.width }
                    SHint {
                        text: page.info ? page.info.os + "  ·  " + page.info.user + "  ·  up " + page.info.uptime : ""
                        width: parent.width
                    }
                }
                Row {
                    id: headButtons
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    SSpinner { anchors.verticalCenter: parent.verticalCenter; running: page.loading }
                    SButton { icon: "󰆏"; text: "Copy"; onClicked: Quickshell.execDetached(["wl-copy", page.summary()]) }
                    SButton { icon: "󰑓"; text: ""; onClicked: page.reload() }
                }
            }

            Row {
                width: parent.width
                spacing: 14
                visible: page.info !== null

                Column {
                    width: (parent.width - 14) / 2
                    spacing: 14

                    Card {
                        width: parent.width
                        title: "System"; icon: "󰌢"
                        Field { label: "OS"; value: page.info?.os ?? "" }
                        Field { label: "Kernel"; value: page.info?.kernel ?? "" }
                        Field { label: "Compositor"; value: "niri " + (page.info?.niri ?? "") }
                        Field { label: "Shell UI"; value: "quickshell " + (page.info?.quickshell ?? "") }
                        Field { label: "Shell"; value: page.info?.shell ?? "" }
                        Field { label: "Booted"; value: page.info?.boot ?? "" }
                    }

                    Card {
                        width: parent.width
                        title: "Displays"; icon: "󰍹"
                        Repeater {
                            model: page.info?.outputs ?? []
                            Field {
                                required property var modelData
                                label: modelData.name
                                value: modelData.model + "\n" + modelData.mode
                                    + (modelData.scale !== 1 ? ", scale " + modelData.scale : "")
                            }
                        }
                    }

                    Card {
                        width: parent.width
                        title: "Packages"; icon: "󰏖"
                        Field { label: "pacman"; value: String(page.info?.packages.pacman ?? "") }
                        Field { label: "AUR"; value: String(page.info?.packages.aur ?? "") }
                        Field { label: "Flatpak"; value: String(page.info?.packages.flatpak ?? "") }
                    }
                }

                Column {
                    width: (parent.width - 14) / 2
                    spacing: 14

                    Card {
                        width: parent.width
                        title: "Hardware"; icon: "󰍛"
                        Field { label: "CPU"; value: (page.info?.cpu ?? "") + "\n" + (page.info?.cores ?? "") + " threads" }
                        Repeater {
                            model: page.info?.gpu ?? []
                            Field {
                                required property var modelData
                                required property int index
                                label: index === 0 ? "GPU" : ""
                                value: modelData
                            }
                        }
                        Field {
                            visible: page.info?.battery != null
                            label: "Battery"
                            value: page.info?.battery
                                ? page.info.battery.capacity + "% · " + page.info.battery.status
                                  + (page.info.battery.health !== null ? " · health " + page.info.battery.health + "%" : "")
                                : ""
                        }
                    }

                    Card {
                        width: parent.width
                        title: "Memory & storage"; icon: "󰋊"
                        Usage {
                            label: "Memory"
                            used: page.info?.memory.used ?? 0
                            total: page.info?.memory.total ?? 1
                            detail: page.info ? page.gib(page.info.memory.used) + " / " + page.gib(page.info.memory.total) : ""
                        }
                        Usage {
                            visible: (page.info?.memory.swapTotal ?? 0) > 0
                            label: "Swap"
                            used: page.info?.memory.swapUsed ?? 0
                            total: page.info?.memory.swapTotal ?? 1
                            detail: page.info ? page.gib(page.info.memory.swapUsed) + " / " + page.gib(page.info.memory.swapTotal) : ""
                        }
                        Repeater {
                            model: page.info?.disks ?? []
                            Usage {
                                required property var modelData
                                label: modelData.mount + "  (" + modelData.fs + ")"
                                used: modelData.used
                                total: modelData.size
                                detail: page.gib(modelData.used) + " / " + page.gib(modelData.size)
                            }
                        }
                    }
                }
            }
        }
    }
}
