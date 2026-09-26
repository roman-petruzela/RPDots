import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Panel s živým logem akce (aktualizace, instalace, firewall). Vyjede zespodu
// přes obsah stránky. Root akce jdou přes polkit — heslo si řekne agent
// (polkit-gnome) vlastním dialogem, sem teče jen výstup pacmanu.
//
//     job.start("Updating system", ["rp-sys", "upgrade"],
//               ["kitty", "--hold", "-e", "sudo", "pacman", "-Syu"], code => reload())
//
// Za běhu nejde zavřít ani zrušit: přerušený pacman uprostřed transakce by
// nechal systém napůl aktualizovaný. Terminálová varianta spustí totéž
// v kitty, kde jde odpovídat na dotazy pacmanu.
Rectangle {
    id: job

    property string title: ""
    property var terminalCommand: []
    property bool open: false
    property int exitCode: -1
    readonly property bool running: proc.running
    property var onDone: null

    signal finished(int code)

    color: Qt.alpha(Colors.surfaceContainer, 0.97)
    radius: 16
    border.width: 1
    border.color: Colors.outlineVariant
    clip: true

    visible: y < parent.height
    y: open ? parent.height - height - 12 : parent.height
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function start(title, command, terminalCommand, onDone) {
        if (proc.running) return false
        job.title = title
        job.terminalCommand = terminalCommand ?? []
        job.onDone = onDone ?? null
        job.exitCode = -1
        lines.clear()
        // Příkazy z ~/.local/bin (rp-sys) nemusí být v PATH quickshellu
        const cmd = command.slice()
        if (!cmd[0].startsWith("/")) cmd[0] = Quickshell.env("HOME") + "/.local/bin/" + cmd[0]
        proc.command = cmd
        proc.running = true
        job.open = true
        return true
    }

    function append(line) {
        lines.append({ line: line })
        if (lines.count > 4000) lines.remove(0, lines.count - 4000)
        logView.positionViewAtEnd()
    }

    function statusText() {
        if (running) return "Running…"
        if (exitCode === 0) return "Done"
        // pkexec: 126 = dialog zrušen / heslo špatně, 127 = bez oprávnění
        // Po 3 chybných heslech (i zrušených dialozích) zamkne faillock účet
        // na 10 minut — pak selže i správné heslo, proto to říct rovnou
        if (exitCode === 126 || exitCode === 127)
            return "Authentication cancelled or failed — after 3 failed attempts the account is locked for 10 minutes"
        return exitCode < 0 ? "" : "Failed (exit code " + exitCode + ")"
    }

    ListModel { id: lines }

    Process {
        id: proc
        stdout: SplitParser { onRead: line => job.append(line) }
        stderr: SplitParser { onRead: line => job.append(line) }
        onExited: code => {
            job.exitCode = code
            job.append(code === 0 ? "── done ──" : "── exit code " + code + " ──")
            if (typeof job.onDone === "function") job.onDone(code)
            job.finished(code)
        }
    }

    // Kliknutí do panelu nepropadne na stránku pod ním
    MouseArea { anchors.fill: parent }

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 54

        SSpinner {
            id: spin
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            running: job.running
        }
        Text {
            id: stateIcon
            visible: !job.running
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            width: 16
            horizontalAlignment: Text.AlignHCenter
            text: job.exitCode === 0 ? "󰄬" : "󰅖"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: job.exitCode === 0 ? Colors.primary : Colors.errorColor
        }
        Column {
            anchors { left: parent.left; leftMargin: 46; right: buttons.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 2
            SLabel { text: job.title; width: parent.width; elide: Text.ElideRight; font.weight: Font.Medium }
            SHint { text: job.statusText(); width: parent.width }
        }
        Row {
            id: buttons
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
            SButton {
                visible: job.terminalCommand.length > 0 && !job.running
                icon: "󰆍"; text: "Terminal"
                onClicked: Quickshell.execDetached(job.terminalCommand)
            }
            SButton {
                icon: "󰆏"; text: ""
                flat: true
                onClicked: {
                    let out = []
                    for (let i = 0; i < lines.count; i++) out.push(lines.get(i).line)
                    Quickshell.execDetached(["wl-copy", out.join("\n")])
                }
            }
            SButton {
                icon: "󰅖"; text: ""
                flat: true
                busy: job.running
                onClicked: job.open = false
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 1
        color: Qt.alpha(Colors.outlineVariant, 0.6)
    }

    ListView {
        id: logView
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; margins: 14; topMargin: 10 }
        clip: true
        model: lines
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: SMono {
            required property string line
            width: logView.width - 12
            text: line
            wrapMode: Text.WrapAnywhere
            color: /^(error|chyba)|failed/i.test(line) ? Colors.errorColor
                : /^(::|──)/.test(line) ? Colors.primary
                : /^warning/i.test(line) ? Colors.tertiary : Colors.onSurfaceVariant
        }
    }
}
