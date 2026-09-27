import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property var workspaces: ({})
    property var windows: ({})
    property int revision: 0

    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
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

    function minimap(wins, highlightId, outputName, boxW, boxH) {
        const scr = Quickshell.screens.find(s => s.name === outputName)
        const outH = scr ? scr.height : 1080
        const gap = 16
        const cols = {}
        for (const w of wins) {
            const key = w.is_floating || !w.layout.pos_in_scrolling_layout
                ? "float" : w.layout.pos_in_scrolling_layout[0]
            ;(cols[key] = cols[key] || []).push(w)
        }
        const keys = Object.keys(cols).filter(k => k !== "float").map(Number).sort((a, b) => a - b)
        if (cols.float) keys.push("float")

        let stripW = gap
        const colW = {}
        for (const k of keys) {
            colW[k] = Math.max(...cols[k].map(w => w.layout.tile_size[0]))
            stripW += colW[k] + gap
        }
        const scale = Math.min(boxW / stripW, boxH / outH)
        const offX = (boxW - stripW * scale) / 2
        const offY = (boxH - outH * scale) / 2

        const tiles = []
        let x = gap
        for (const k of keys) {
            const col = cols[k].slice().sort((a, b) =>
                (a.layout.pos_in_scrolling_layout?.[1] ?? 0) - (b.layout.pos_in_scrolling_layout?.[1] ?? 0))
            let y = gap
            for (const w of col) {
                const [tw, th] = w.layout.tile_size
                tiles.push({
                    x: offX + x * scale, y: offY + y * scale,
                    w: Math.max(tw * scale, 4), h: Math.max(th * scale, 4),
                    appId: w.app_id ?? "", hl: w.id === highlightId
                })
                y += th + gap
            }
            x += colW[k] + gap
        }
        return tiles
    }

    function outputLabel(name) {
        if (name.startsWith("eDP")) return "Laptop"
        const scr = Quickshell.screens.find(s => s.name === name)
        return scr?.model || name
    }

    function appIcon(appId) {
        const entry = DesktopEntries.heuristicLookup(appId)
        return Quickshell.iconPath(entry?.icon ?? appId, true)
            || Quickshell.iconPath("application-x-executable")
    }

    function appName(appId) {
        return DesktopEntries.heuristicLookup(appId)?.name || appId
    }
}
