import Quickshell
import Quickshell.Io
import QtQuick
import "."

ShellRoot {
    id: root

    property bool dashboardVisible: false

    IpcHandler {
        target: "toggle-dashboard"
        function onMessage() {
            root.dashboardVisible = !root.dashboardVisible
        }
    }

    IpcHandler {
        target: "reload-colors"
        function onMessage() {
            Quickshell.reload(false)
        }
    }

    Dashboard {
        visible: root.dashboardVisible
    }
}
