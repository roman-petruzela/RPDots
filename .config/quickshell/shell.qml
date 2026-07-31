import Quickshell
import Quickshell.Io
import QtQuick
import "."

ShellRoot {
    id: root

    property bool dashboardVisible: false

    IpcHandler {
        target: "dashboard"
        function toggle(): void {
            root.dashboardVisible = !root.dashboardVisible
        }
    }

    IpcHandler {
        target: "shell"
        function reload(): void {
            Quickshell.reload(true)
        }
    }

    Dashboard {
        visible: root.dashboardVisible
    }

    OSD {}
}
