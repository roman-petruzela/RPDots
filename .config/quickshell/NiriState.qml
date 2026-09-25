import Quickshell
import Quickshell.Io
import QtQuick

// Živý stav niri (workspacy + okna) z `niri msg --json event-stream`.
// Stream na začátku pošle celý stav (WorkspacesChanged, WindowsChanged) a pak
// jen změny, takže přepínače se otevírají okamžitě — bez `niri msg` při
// každém stisku (~13 ms a proces navíc).
//
// Objekty se mění na místě; kdo potřebuje reagovat, sleduje `revision`.
Item {
    id: root

    property var workspaces: ({})   // id -> workspace z niri IPC
    property var windows: ({})      // id -> okno z niri IPC
    property int revision: 0

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        // niri restart / reload sezení — připojit se znovu
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: stream.running = true
    }

    function handle(line) {
        let ev
        try { ev = JSON.parse(line) } catch (e) { return }
        const name = Object.keys(ev)[0]
        const d = ev[name]

        switch (name) {
        case "WorkspacesChanged": {
            const m = {}
            for (const w of d.workspaces) m[w.id] = w
            workspaces = m
            break
        }
        case "WorkspaceActivated": {
            const target = workspaces[d.id]
            if (!target) return
            for (const w of Object.values(workspaces)) {
                if (w.output === target.output) w.is_active = w.id === d.id
                if (d.focused) w.is_focused = w.id === d.id
            }
            break
        }
        case "WorkspaceActiveWindowChanged": {
            const w = workspaces[d.workspace_id]
            if (!w) return
            w.active_window_id = d.active_window_id
            break
        }
        case "WindowsChanged": {
            const m = {}
            for (const w of d.windows) m[w.id] = w
            windows = m
            break
        }
        case "WindowOpenedOrChanged": {
            if (d.window.is_focused)
                for (const w of Object.values(windows)) w.is_focused = false
            windows[d.window.id] = d.window
            break
        }
        case "WindowClosed":
            delete windows[d.id]
            break
        case "WindowFocusChanged":
            for (const w of Object.values(windows)) w.is_focused = w.id === d.id
            break
        case "WindowFocusTimestampChanged": {
            const w = windows[d.id]
            if (!w) return
            w.focus_timestamp = d.focus_timestamp
            break
        }
        case "WindowLayoutsChanged":
            for (const [id, layout] of d.changes) {
                const w = windows[id]
                if (w) w.layout = layout
            }
            break
        default:
            return
        }
        revision++
    }

    function focusedWorkspace() {
        return Object.values(workspaces).find(w => w.is_focused) ?? null
    }

    function stamp(win) {
        const t = win.focus_timestamp
        return t ? t.secs * 1e9 + t.nanos : 0
    }
}
