import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import "../Colors.js" as Colors

Scope {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string wallpaper: Quickshell.env("HOME") + "/.local/share/wallpapers/current"
    readonly property string flag: Quickshell.env("XDG_RUNTIME_DIR") + "/rp-locked"
    readonly property string captureDir: Quickshell.env("XDG_RUNTIME_DIR") + "/rp-lock"

    property string password: ""
    property bool busy: false
    property string message: ""
    property int failures: 0
    property string layout: ""
    property bool unlocking: false

    function lock() {
        if (lockState.locked || capture.running) return
        unlocking = false
        layoutQuery.running = true
        capture.running = true
        captureTimeout.restart()
    }

    function engage() {
        captureTimeout.stop()
        lockState.locked = true
    }

    Process {
        id: capture
        command: ["bash", "-c", `d="${root.captureDir}"; mkdir -p "$d"; rm -f "$d"/*.png
            for o in $(niri msg --json outputs | jq -r 'to_entries[] | select(.value.logical != null) | .key'); do
                grim -l 0 -o "$o" "$d/$o.png" &
            done; wait`]
        onExited: root.engage()
    }
    Timer { id: captureTimeout; interval: 1500; onTriggered: { capture.running = false; root.engage() } }

    function refreshLayout() { layoutQuery.running = false; layoutQuery.running = true }

    function submit() {
        if (busy || password === "") return
        busy = true
        message = ""
        if (!pam.start()) fail("Authentication is unavailable")
    }

    function fail(text) {
        busy = false
        password = ""
        message = text
        failures++
    }

    PersistentProperties {
        id: lockState
        reloadableId: "rp-lock"
        property bool locked: false
    }

    WlSessionLock {
        id: sessionLock
        locked: lockState.locked
        onSecureChanged: Quickshell.execDetached(secure ? ["touch", root.flag] : ["rm", "-f", root.flag])

        WlSessionLockSurface {
            id: surface
            color: Colors.background

            LockContent {
                anchors.fill: parent
                host: root
                backdrop: surface.screen ? root.captureDir + "/" + surface.screen.name + ".png" : ""
                focus: true
            }
        }
    }

    Timer {
        id: unlockTimer
        interval: 420
        onTriggered: {
            lockState.locked = false
            root.unlocking = false
            Quickshell.execDetached(["rm", "-rf", root.captureDir])
            root.busy = false
            root.password = ""
        }
    }

    PamContext {
        id: pam
        config: "swaylock"
        onResponseRequiredChanged: if (responseRequired) respond(root.password)
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.message = ""
                root.unlocking = true
                unlockTimer.restart()
            } else {
                root.fail("Wrong password")
            }
        }
        onError: err => root.fail("Authentication error")
        onMessageChanged: if (messageIsError && message !== "") root.message = message
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
}
