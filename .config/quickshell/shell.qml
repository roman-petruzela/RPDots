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

    property bool dashboardVisible: false

    IpcHandler {
        target: "dashboard"
        function toggle(): void {
            root.dashboardVisible = !root.dashboardVisible
        }
    }

    // Pozor: funkce se nesmí jmenovat `show` — kolidovalo by to
    // s podpříkazem `qs ipc show` a volání by se jen vypsalo.
    IpcHandler {
        target: "audio"
        function toggle(): void { audioSwitcher.toggle() }
        function open(): void   { audioSwitcher.openSwitcher() }
        function hide(): void   { audioSwitcher.visible = false }
        function next(): void   { audioSwitcher.selectNext() }
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
        visible: root.dashboardVisible
    }

    AudioSwitcher {
        id: audioSwitcher
    }

    OSD {}
}
