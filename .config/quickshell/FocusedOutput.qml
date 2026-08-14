import Quickshell
import Quickshell.Io

// Zjistí, na kterém výstupu niri právě pracuje, nastaví ho oknu a teprve pak
// ho zobrazí. Kdyby se obrazovka měnila až po zobrazení, okno by při každém
// otevření viditelně poskočilo na jiný monitor.
//
//     FocusedOutput { id: opener; window: root }
//     function open() { opener.show() }
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
                // niri neodpovědělo — zůstaneme na výchozí obrazovce
            }
            root.window.visible = true
        }
    }

    function show() {
        running = false
        running = true
    }
}
