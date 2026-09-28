import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick
import "Colors.js" as Colors
import "lock"

ShellRoot {
    id: root

    readonly property string user: Quickshell.env("RP_GREETER_USER") || ""
    readonly property bool testMode: Quickshell.env("RP_GREETER_TEST") === "1"
    readonly property string onlyScreen: Quickshell.env("RP_GREETER_SCREEN") || ""
    readonly property string wallpaper: Quickshell.env("RP_GREETER_WALLPAPER")
        || "/usr/share/backgrounds/rprice-current.jpg"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    property string password: ""
    property bool busy: false
    property string message: ""
    property int failures: 0
    property string layout: ""
    property bool unlocking: false

    function submit() {
        if (busy || password === "") return
        busy = true
        message = ""
        if (testMode) {
            testTimer.start()
            return
        }
        Greetd.createSession(user)
    }

    function fail(text) {
        busy = false
        password = ""
        message = text
        failures++
    }

    function launch() {
        message = ""
        unlocking = true
        launchTimer.start()
    }

    function refreshLayout() { layoutQuery.running = false; layoutQuery.running = true }

    function power(action) {
        if (testMode) {
            console.log("rp-greeter test: systemctl", action)
            return
        }
        Quickshell.execDetached(["systemctl", action])
    }

    Timer {
        id: testTimer
        interval: 600
        onTriggered: {
            if (root.password === "test") root.launch()
            else root.fail("Wrong password")
        }
    }

    Timer {
        id: launchTimer
        interval: 420
        onTriggered: {
            if (root.testMode) Qt.quit()
            else Greetd.launch(["niri-session"], [], true)
        }
    }

    Connections {
        target: Greetd
        enabled: !root.testMode

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.password)
            else if (error) root.message = message
        }
        function onAuthFailure(message) {
            Greetd.cancelSession()
            root.fail("Wrong password")
        }
        function onReadyToLaunch() {
            root.launch()
        }
        function onError(error) {
            root.fail(error)
        }
    }

    Process {
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                let ev
                try { ev = JSON.parse(line) } catch (e) { return }
                if (ev.KeyboardLayoutsChanged) {
                    const k = ev.KeyboardLayoutsChanged.keyboard_layouts
                    root.layout = k.names[k.current_idx] ?? ""
                } else if (ev.KeyboardLayoutSwitched) {
                    layoutQuery.running = true
                }
            }
        }
    }

    Process {
        id: layoutQuery
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const k = JSON.parse(text)
                    root.layout = k.names[k.current_idx] ?? ""
                } catch (e) {}
            }
        }
    }

    Variants {
        model: root.onlyScreen !== ""
            ? Quickshell.screens.filter(s => s.name === root.onlyScreen)
            : Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Colors.background
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rp-greeter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockContent {
                anchors.fill: parent
                host: root
                wallpaper: root.wallpaper
                user: root.user
                focus: true
            }
        }
    }
}
