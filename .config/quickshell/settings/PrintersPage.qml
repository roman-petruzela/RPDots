import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Tiskárny (CUPS): seznam, výchozí tiskárna, zkušební stránka, fronta úloh.
// Přidání a pokročilé nastavení tiskárny nechává na system-config-printer
// nebo webovém rozhraní CUPS.
Item {
    id: page
    required property var host

    property var pr: null

    function reload() { proc.running = false; proc.running = true }
    Component.onCompleted: reload()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.reload() }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "printers"]
        stdout: StdioCollector { onStreamFinished: { try { page.pr = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: actProc
        stdout: StdioCollector { onStreamFinished: if (text.trim()) page.host.showInfo(text.trim()) }
        onExited: page.reload()
    }
    function printer(args) {
        actProc.running = false
        actProc.command = [Quickshell.env("HOME") + "/.local/bin/rp-sys", "printer"].concat(args)
        actProc.running = true
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

            SHint {
                visible: page.pr !== null && !page.pr.cups
                leftPadding: 14; bottomPadding: 8
                color: Colors.errorColor
                text: "The CUPS service isn't running — printing won't work."
            }

            SHeading { text: "PRINTERS" }
            SHint {
                visible: (page.pr?.printers.length ?? 0) === 0
                leftPadding: 14; bottomPadding: 6
                text: "No printers set up."
            }
            Repeater {
                model: page.pr?.printers ?? []
                SRow {
                    required property var modelData
                    icon: "󰐪"
                    label: modelData.name + (modelData.default ? "  ·  default" : "")
                    hint: modelData.state
                    Row {
                        spacing: 8
                        SButton {
                            visible: !modelData.default
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰄬"; text: "Make default"
                            onClicked: page.printer(["default", modelData.name])
                        }
                        SButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰐪"; text: "Test page"
                            onClicked: page.printer(["test", modelData.name])
                        }
                    }
                }
            }

            SHeading { text: "PRINT QUEUE" }
            SHint {
                visible: (page.pr?.jobs.length ?? 0) === 0
                leftPadding: 14; bottomPadding: 6
                text: "Nothing waiting to print."
            }
            Repeater {
                model: page.pr?.jobs ?? []
                SRow {
                    required property var modelData
                    label: modelData.id
                    hint: modelData.user + " · " + modelData.date
                }
            }
            SRow {
                visible: (page.pr?.jobs.length ?? 0) > 0
                label: "Cancel all jobs"
                SButton {
                    danger: true
                    icon: "󰜺"; text: "Cancel all"
                    onClicked: page.printer(["cancel", page.pr.default])
                }
            }

            SHeading { text: "SET UP" }
            SRow {
                label: "Add or configure a printer"
                hint: "Drivers, paper, duplex — system-config-printer."
                SButton {
                    visible: page.pr?.configTool ?? false
                    icon: "󰏌"; text: "Open"
                    onClicked: Quickshell.execDetached(["system-config-printer"])
                }
            }
            SRow {
                label: "CUPS web interface"
                hint: "http://localhost:631 — everything CUPS can do."
                SButton { icon: "󰖟"; text: "Open"; onClicked: Quickshell.execDetached(["xdg-open", "http://localhost:631"]) }
            }
        }
    }
}
