//@ pragma IconTheme Papirus-Dark
// Bez tohohle quickshell hledá ikony jen v hicolor a obecné názvy
// (utilities-system-monitor, …) vykreslí jako šachovnici.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "."

ShellRoot {
    id: root

    // Barem je waybar — quickshell tu jede jen kvůli OSD, dashboardu
    // a přepínači zvuku. Přepni na true, pokud chceš zpátky qs bar.
    property bool useBar: false

    IpcHandler {
        target: "dashboard"
        function toggle(): void { root.openFlyout(dashboard, true) }
        function open(): void   { root.openFlyout(dashboard, false) }
        function hide(): void   { dashboard.visible = false }
    }

    // Pozor: funkce se nesmí jmenovat `show` — kolidovalo by to
    // s podpříkazem `qs ipc show` a volání by se jen vypsalo.
    IpcHandler {
        target: "audio"
        function toggle(): void { root.openFlyout(audioSwitcher, true) }
        function open(): void   { root.openFlyout(audioSwitcher, false) }
        function hide(): void   { audioSwitcher.visible = false }
        function next(): void   { audioSwitcher.selectNext() }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.openFlyout(powerSwitcher, true) }
        function open(): void   { root.openFlyout(powerSwitcher, false) }
        function hide(): void   { powerSwitcher.visible = false }
    }

    IpcHandler {
        target: "network"
        function toggle(): void { root.openFlyout(networkSwitcher, true) }
        function open(): void   { root.openFlyout(networkSwitcher, false) }
        function hide(): void   { networkSwitcher.visible = false }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.openFlyout(launcher, true) }
        function hide(): void   { launcher.visible = false }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.openFlyout(clipboardHistory, true) }
        function hide(): void   { clipboardHistory.visible = false }
    }

    IpcHandler {
        target: "session"
        function toggle(): void { root.openFlyout(sessionMenu, true) }
        function hide(): void   { sessionMenu.visible = false }
    }

    IpcHandler {
        target: "windows"
        function next(): void { root.dispatch("windows next") }
        function prev(): void { root.dispatch("windows prev") }
        function hide(): void { winSwitcher.hide() }
    }

    IpcHandler {
        target: "workspaces"
        function next(): void { wsSwitcher.cycle(1) }
        function prev(): void { wsSwitcher.cycle(-1) }
        function hide(): void { wsSwitcher.hide() }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.openFlyout(wallpaperPicker, true) }
        function open(): void   { root.openFlyout(wallpaperPicker, false) }
        function hide(): void   { wallpaperPicker.visible = false }
    }

    // Okna vyjíždějí na stejné místo, takže se navzájem vylučují.
    function openFlyout(target, allowToggle) {
        for (const f of [dashboard, audioSwitcher, powerSwitcher, networkSwitcher, wallpaperPicker, launcher, sessionMenu, clipboardHistory])
            if (f !== target) f.visible = false

        if (allowToggle) target.toggle()
        else target.open()
    }

    // Rychlá cesta pro klávesové zkratky a waybar: `rp-shell <cíl> <funkce>`
    // pošle řádek "cíl funkce" na tenhle socket. `qs ipc call` pokaždé startuje
    // celý Qt klient (~40 ms), což je u OSD hlasitosti a otevírání oken znát;
    // socat na socket trvá pár ms. IpcHandlery výš zůstávají pro kompatibilitu.
    SocketServer {
        active: true
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/rp-shell.sock"
        // Spojení zavírá server hned po přečtení příkazu — kdyby ho zavřel
        // klient, quickshell by každé volání zalogoval jako PeerClosedError.
        handler: Socket {
            id: client
            parser: SplitParser {
                onRead: line => {
                    root.dispatch(line.trim())
                    client.connected = false
                }
            }
        }
    }

    function dispatch(line) {
        // Přepínače (Mod+Tab / Alt+Tab) se navzájem vylučují
        const [t, f] = line.split(/\s+/)
        if (t === "workspaces" || t === "windows") {
            const sw = t === "workspaces" ? wsSwitcher : winSwitcher
            const other = t === "workspaces" ? winSwitcher : wsSwitcher
            other.hide()
            if (f === "hide") sw.hide()
            else sw.cycle(f.startsWith("prev") ? -1 : 1, f.endsWith("-app"))
            return
        }

        const flyouts = {
            dashboard: dashboard, audio: audioSwitcher, power: powerSwitcher,
            network: networkSwitcher, wallpaper: wallpaperPicker,
            launcher: launcher, session: sessionMenu, clipboard: clipboardHistory
        }
        const [target, fn] = line.split(/\s+/)
        const flyout = flyouts[target]
        if (flyout) {
            if (fn === "toggle") root.openFlyout(flyout, true)
            else if (fn === "open") root.openFlyout(flyout, false)
            else if (fn === "hide") flyout.visible = false
            else if (fn === "next" && target === "audio") audioSwitcher.selectNext()
            return
        }
        if (line === "osd-volume trigger") osd.triggerVolume()
        else if (line === "osd-brightness trigger") osd.triggerBrightness()
        else if (line === "osd-keyboard-layout trigger") osd.triggerKeyboardLayout()
        else console.warn("rp-shell: unknown command:", line)
    }

    IpcHandler {
        target: "shell"
        function reload(): void {
            Quickshell.reload(true)
        }
    }

    // Bar on every connected screen
    Variants {
        model: root.useBar ? Quickshell.screens : []
        delegate: Bar {}
    }

    Dashboard {
        id: dashboard
    }

    AudioSwitcher {
        id: audioSwitcher
    }

    PowerSwitcher {
        id: powerSwitcher
    }

    NetworkSwitcher {
        id: networkSwitcher
    }

    WallpaperPicker {
        id: wallpaperPicker
    }

    Launcher { id: launcher }

    SessionMenu { id: sessionMenu }

    ClipboardHistory { id: clipboardHistory }

    NiriState { id: niri }

    WorkspaceSwitcher {
        id: wsSwitcher
        niri: niri
    }

    WindowSwitcher {
        id: winSwitcher
        niri: niri
    }

    // Náhled vybrané tapety pod okny, na všech monitorech
    Variants {
        model: Quickshell.screens
        delegate: WallpaperPreview {
            required property var modelData
            screen: modelData
            active: wallpaperPicker.previewActive
            source: wallpaperPicker.previewSource
        }
    }

    OSD { id: osd }
}
