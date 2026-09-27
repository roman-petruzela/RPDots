import Quickshell
import Quickshell.Io

Process {
    id: root

    required property var window

    command: ["niri", "msg", "--json", "focused-output"]

    stdout: StdioCollector {
        onStreamFinished: {
            try {
                const name = JSON.parse(text).name
                const match = Quickshell.screens.find(s => s.name === name)
                if (match) root.window.screen = match
            } catch (e) {
            }
            root.window.visible = true
        }
    }

    function show() {
        running = false
        running = true
    }
}
