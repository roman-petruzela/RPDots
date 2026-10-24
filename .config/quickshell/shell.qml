//@ pragma IconTheme Papirus-Dark
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "."
import "bar"
import "notify"
import "lock"

ShellRoot {
    id: root

    BarData { id: barSource; active: true }
    readonly property var niriRef: niri

    IpcHandler {
        target: "dashboard"
        function toggle(): void { root.openFlyout(dashboard, true) }
        function open(): void   { root.openFlyout(dashboard, false) }
        function hide(): void   { dashboard.hide() }
    }

    IpcHandler {
        target: "audio"
        function toggle(): void { root.openFlyout(audioSwitcher, true) }
        function open(): void   { root.openFlyout(audioSwitcher, false) }
        function hide(): void   { audioSwitcher.hide() }
        function next(): void   { audioSwitcher.selectNext() }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.openFlyout(powerSwitcher, true) }
        function open(): void   { root.openFlyout(powerSwitcher, false) }
        function hide(): void   { powerSwitcher.hide() }
    }

    IpcHandler {
        target: "network"
        function toggle(): void { root.openFlyout(networkSwitcher, true) }
        function open(): void   { root.openFlyout(networkSwitcher, false) }
        function hide(): void   { networkSwitcher.hide() }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.openFlyout(launcher, true) }
        function hide(): void   { launcher.hide() }
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
        target: "settings"
        function toggle(): void { settingsWindow.toggle() }
        function open(): void   { settingsWindow.open() }
        function hide(): void   { settingsWindow.hide() }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.openFlyout(wallpaperPicker, true) }
        function open(): void   { root.openFlyout(wallpaperPicker, false) }
        function hide(): void   { wallpaperPicker.visible = false }
    }

    function barAnchor(output, key) {
        const b = bars.instances.find(b => b.output === output)
        return b ? b.anchorFor(key) : -1
    }

    function openFlyout(target, allowToggle) {
        for (const f of [dashboard, audioSwitcher, powerSwitcher, networkSwitcher, wallpaperPicker, launcher, sessionMenu, clipboardHistory])
            if ([dashboard, audioSwitcher, powerSwitcher, networkSwitcher].includes(f) && f !== target) f.hide()
            else if (f !== target) f.visible = false

        if (allowToggle) target.toggle()
        else target.open()
    }

    SocketServer {
        active: true
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/rp-shell.sock"
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
            else if (fn === "hide") { if (flyout.hide) flyout.hide(); else flyout.visible = false }
            else if (fn === "next" && target === "audio") audioSwitcher.selectNext()
            return
        }
        if (target === "settings") {
            if (fn === "toggle") settingsWindow.toggle()
            else if (fn === "open") settingsWindow.open()
            else if (fn === "hide") settingsWindow.hide()
            else if (!settingsWindow.openPage(fn)) console.warn("rp-shell: unknown settings page:", fn)
            return
        }
        if (line === "lock lock") { lockScreen.lock(); return }
        if (line === "identify run") { identify.run(); return }
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

    Variants {
        id: bars
        model: Quickshell.screens
        delegate: TopBar { barData: barSource; niri: root.niriRef }
    }

    Caffeine { id: caffeine }

    Dashboard {
        id: dashboard
        barData: barSource
        caffeine: caffeine
        notify: notifyService
    }

    AudioSwitcher {
        id: audioSwitcher
        anchorFn: output => root.barAnchor(output, "audio")
    }

    PowerSwitcher {
        id: powerSwitcher
        anchorFn: output => root.barAnchor(output, "power")
    }

    NetworkSwitcher {
        id: networkSwitcher
        anchorFn: output => root.barAnchor(output, "network")
    }

    WallpaperPicker {
        id: wallpaperPicker
    }

    Launcher { id: launcher; niri: niri }

    SessionMenu { id: sessionMenu }

    ClipboardHistory { id: clipboardHistory }

    Settings { id: settingsWindow }

    PolkitDialog {}

    LockScreen { id: lockScreen }
    IdentifyOverlay { id: identify }

    IpcHandler {
        target: "lock"
        function lock(): void { lockScreen.lock() }
    }

    NotifyService { id: notifyService }
    NotifyPopups { service: notifyService; niri: root.niriRef; rightInset: dashboard.visible ? 380 : 0 }

    NiriState { id: niri }

    WorkspaceSwitcher {
        id: wsSwitcher
        niri: niri
    }

    WindowSwitcher {
        id: winSwitcher
        niri: niri
    }

    Variants {
        model: Quickshell.screens
        delegate: WallpaperPreview {
            required property var modelData
            screen: modelData
            active: wallpaperPicker.previewActive
            source: wallpaperPicker.previewSource
            thumb: wallpaperPicker.previewThumb
        }
    }

    OSD { id: osd; niri: root.niriRef }
}
