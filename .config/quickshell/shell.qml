import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "."

ShellRoot {
    id: root

    // Barem je waybar — quickshell tu jede jen kvůli OSD, dashboardu
    // a přepínačům pod barem.
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

    // Okna vyjíždějí na stejné místo, takže se navzájem vylučují.
    function openFlyout(target, allowToggle) {
        for (const f of [dashboard, audioSwitcher, powerSwitcher, networkSwitcher])
            if (f !== target) f.visible = false

        if (allowToggle) target.toggle()
        else target.open()
    }

    IpcHandler {
        target: "shell"
        function reload(): void {
            Quickshell.reload(true)
        }
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

    OSD {}
}
