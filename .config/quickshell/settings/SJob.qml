import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

Rectangle {
    id: job

    property string title: ""
    property var terminalCommand: []
    property bool open: false
    property bool minimized: false
    property real fullHeight: 420
    property int exitCode: -1
    property bool started: false
    readonly property bool running: started && exitCode < 0
    property var onDone: null
    readonly property string rpJob: Quickshell.env("HOME") + "/.local/bin/rp-job"

    signal finished(int code)

    color: Qt.alpha(Colors.surfaceContainer, 0.97)
    topLeftRadius: 16
    topRightRadius: 16
    bottomLeftRadius: 0
    bottomRightRadius: 0
    clip: true

    property real slide: open ? 1 : 0
    Behavior on slide { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    height: minimized ? header.height : fullHeight
    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    y: parent.height - height * slide
    visible: slide > 0
    readonly property real occupied: height * slide

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: parent.height + radius
        radius: 16
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.8)
        z: 10
    }

    function start(title, command, terminalCommand, onDone) {
        if (running) return false
        job.title = title
        job.terminalCommand = terminalCommand ?? []
        job.onDone = onDone ?? null
        job.exitCode = -1
        job.minimized = false
        lines.clear()
        const cmd = command.slice()
        if (!cmd[0].startsWith("/")) cmd[0] = Quickshell.env("HOME") + "/.local/bin/" + cmd[0]
        startProc.command = [rpJob, "start", title, JSON.stringify(job.terminalCommand), "--"].concat(cmd)
        startProc.running = true
        job.started = true
        job.open = true
        return true
    }

    onOpenChanged: if (!open && started && !running) {
        Quickshell.execDetached([rpJob, "dismiss"])
        started = false
    }

    function follow() {
        tailProc.running = false
        tailProc.command = ["tail", "-n", "+1", "-F", Quickshell.env("XDG_RUNTIME_DIR") + "/rp-job/log"]
        tailProc.running = true
    }

    Component.onCompleted: statusProc.running = true
    Process {
        id: statusProc
        command: [job.rpJob, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let st = {}
                try { st = JSON.parse(text) } catch (e) { return }
                if (!st.title) return
                job.title = st.title
                job.terminalCommand = st.terminal ?? []
                job.exitCode = -1
                job.started = true
                job.open = true
                lines.clear()
                job.follow()
            }
        }
    }
    Process {
        id: startProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") { job.append(text.trim()); job.exitCode = 1 }
        }
        onExited: code => { if (code === 0) job.follow() }
    }

    function append(line) {
        lines.append({ line: line })
        if (lines.count > 4000) lines.remove(0, lines.count - 4000)
        logView.positionViewAtEnd()
    }

    function statusText() {
        if (running) return "Running…"
        if (exitCode === 0) return "Done"
        if (exitCode === 126 || exitCode === 127)
            return "Authentication cancelled or failed — after 3 failed attempts the account is locked for 10 minutes"
        return exitCode < 0 ? "" : "Failed (exit code " + exitCode + ")"
    }

    ListModel { id: lines }

    Process {
        id: tailProc
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/^── exit (\d+) ──$/)
                if (!m) { job.append(line); return }
                const code = Number(m[1])
                job.exitCode = code
                job.append(code === 0 ? "── done ──" : "── exit code " + code + " ──")
                tailProc.running = false
                if (typeof job.onDone === "function") job.onDone(code)
                job.onDone = null
                job.finished(code)
            }
        }
    }

    MouseArea { anchors.fill: parent }

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 54

        TapHandler { enabled: job.minimized; onTapped: job.minimized = false }
        HoverHandler { enabled: job.minimized; cursorShape: Qt.PointingHandCursor }

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
            color: job.exitCode === 0 ? Colors.accent2 : Colors.errorColor
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
                visible: job.started
                icon: "󰆍"; text: "Terminal"
                onClicked: Quickshell.execDetached(["kitty", "--title", "RPSettings: " + job.title, "-e", "bash", "-c",
                    'd="$XDG_RUNTIME_DIR/rp-job"; tail -n +1 -F --pid="$(cat "$d/pid")" "$d/log" 2>/dev/null; '
                    + 'echo; read -rsn1 -p "Press any key to close…"'])
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
                icon: job.minimized ? "󰅃" : "󰅀"; text: ""
                flat: true
                onClicked: job.minimized = !job.minimized
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
        visible: !job.minimized
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: 1
        color: Qt.alpha(Colors.outlineVariant, 0.6)
    }

    SWheel { flick: logView }
    ListView {
        id: logView
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; margins: 14; topMargin: 10 }
        clip: true
        model: lines
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}
        delegate: SMono {
            required property string line
            width: logView.width - 12
            text: line
            wrapMode: Text.WrapAnywhere
            color: /^(error|chyba)|failed/i.test(line) ? Colors.errorColor
                : /^(::|──)/.test(line) ? Colors.accent2
                : /^warning/i.test(line) ? Colors.tertiary : Colors.onSurfaceVariant
        }
    }
}
