import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick
import QtQuick.Effects
import "Colors.js" as Colors

// Přihlašovací obrazovka (greetd + niri + quickshell), ve stylu pickeru tapet:
// rozmazaná tapeta, nahoře hodiny, uprostřed jen pole na heslo, dole vypnutí.
// Žádný avatar ani výběr uživatele — uživatel je jeden (RP_GREETER_USER,
// doplní install.sh do niri.kdl).
//
// Běží pod uživatelem `greeter`, který nevidí do /home — tapetu a Colors.js
// sem kopíruje rp-lightdm-sync-apply při každé změně tématu.
//
// Náhled v běžné session: ~/.local/share/rp-greeter/preview.sh
// (RP_GREETER_TEST=1: bez greetd, heslo „test“ projde, cokoli jiného selže).
ShellRoot {
    id: root

    readonly property string user: Quickshell.env("RP_GREETER_USER") || "roman"
    readonly property bool testMode: Quickshell.env("RP_GREETER_TEST") === "1"
    readonly property string onlyScreen: Quickshell.env("RP_GREETER_SCREEN") || ""
    readonly property string wallpaper: Quickshell.env("RP_GREETER_WALLPAPER")
        || "/usr/share/backgrounds/rprice-current.jpg"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // Heslo drží ShellRoot, ne TextInput: okno je na každém monitoru a psát
    // se dá do kteréhokoli z nich
    property string password: ""
    property bool busy: false
    property string message: ""
    property int failures: 0
    property string layout: ""

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
            if (root.password === "test") Qt.quit()
            else root.fail("Wrong password")
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
            // quit=true: quickshell skončí a niri.kdl pak ukončí i greeterové niri,
            // teprve potom greetd spustí session
            Greetd.launch(["niri-session"], [], true)
        }
        function onError(error) {
            root.fail(error)
        }
    }

    // Aktuální rozložení klávesnice (cz/us) — u hesla na tom záleží
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

    function shortLayout(name) {
        if (name.startsWith("Czech")) return "CZ"
        if (name.startsWith("English")) return "US"
        return name.slice(0, 2).toUpperCase()
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

            Image {
                id: wall
                anchors.fill: parent
                source: "file://" + root.wallpaper
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(win.width / 2, win.height / 2)
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                saturation: 0.1
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(Colors.background, 0.35) }
                    GradientStop { position: 0.55; color: Qt.alpha(Colors.background, 0.45) }
                    GradientStop { position: 1.0; color: Qt.alpha(Colors.background, 0.8) }
                }
            }

            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.submit()
                    } else if (event.key === Qt.Key_Escape) {
                        if (!root.busy) { root.password = ""; root.message = "" }
                    } else if (event.key === Qt.Key_Backspace) {
                        if (!root.busy) root.password = (event.modifiers & Qt.ControlModifier)
                            ? "" : root.password.slice(0, -1)
                    } else if (event.text.length > 0 && event.text >= " " && !root.busy) {
                        root.password += event.text
                        root.message = ""
                    } else {
                        return
                    }
                    event.accepted = true
                }

                // ----------------------------------------------------- top

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height * 0.12)
                    spacing: 6

                    Text {
                        id: clock
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: root.fontFamily
                        font.pixelSize: 88
                        font.weight: Font.Light
                        color: Colors.onSurface
                    }
                    Text {
                        id: date
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: root.fontFamily
                        font.pixelSize: 17
                        color: Colors.onSurfaceVariant
                    }

                    Timer {
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        interval: 1000
                        onTriggered: {
                            const now = new Date()
                            clock.text = Qt.formatTime(now, "HH:mm")
                            date.text = now.toLocaleDateString(Qt.locale(), "dddd d MMMM")
                        }
                    }
                }

                // -------------------------------------------------- center

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 30
                    spacing: 14

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.user
                        font.family: root.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Colors.onSurface
                    }

                    Rectangle {
                        id: field
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 400
                        height: 58
                        radius: 29
                        color: Qt.alpha(Colors.surfaceContainerHigh, 0.82)
                        border.width: 2
                        border.color: root.message !== "" ? Colors.errorColor
                            : root.busy ? Qt.alpha(Colors.primary, 0.5) : Colors.primary

                        // Zatřesení po špatném heslu
                        property real shake: 0
                        transform: Translate { x: field.shake }
                        SequentialAnimation {
                            id: shakeAnim
                            loops: 1
                            NumberAnimation { target: field; property: "shake"; to: -10; duration: 45 }
                            NumberAnimation { target: field; property: "shake"; to: 9; duration: 70 }
                            NumberAnimation { target: field; property: "shake"; to: -6; duration: 60 }
                            NumberAnimation { target: field; property: "shake"; to: 0; duration: 50 }
                        }
                        Connections {
                            target: root
                            function onFailuresChanged() { shakeAnim.restart() }
                        }

                        Text {
                            anchors { left: parent.left; leftMargin: 26; right: layoutChip.left
                                      rightMargin: 12; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideLeft
                            text: root.busy ? "Signing in…"
                                : root.password === "" ? "Password"
                                : "•".repeat(root.password.length)
                            font.family: root.fontFamily
                            font.pixelSize: root.password === "" || root.busy ? 16 : 22
                            font.letterSpacing: root.password === "" || root.busy ? 0 : 3
                            color: root.password === "" || root.busy
                                ? Qt.alpha(Colors.onSurfaceVariant, 0.7) : Colors.onSurface
                        }

                        // Rozložení klávesnice; klik přepne (jako Alt+Shift)
                        Rectangle {
                            id: layoutChip
                            visible: root.layout !== ""
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            width: 44
                            height: 34
                            radius: 17
                            color: Qt.alpha(Colors.primaryContainer, 0.9)
                            Text {
                                anchors.centerIn: parent
                                text: root.shortLayout(root.layout)
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Colors.onPrimaryContainer
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 20
                        text: root.message
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        color: Colors.errorColor
                    }
                }

                // -------------------------------------------------- bottom

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    spacing: 12

                    Repeater {
                        // Glyfy FontAwesome z Nerd Fontu: moon-o, refresh, power-off
                        model: [["", "Suspend", "suspend"],
                                ["", "Restart", "reboot"],
                                ["", "Shut down", "poweroff"]]

                        Rectangle {
                            id: pill
                            required property var modelData
                            width: pillRow.implicitWidth + 36
                            height: 44
                            radius: 22
                            color: hover.containsMouse
                                ? Qt.alpha(Colors.surfaceContainerHighest, 0.9)
                                : Qt.alpha(Colors.surfaceContainer, 0.6)
                            border.width: 1
                            border.color: Qt.alpha(Colors.onSurface, hover.containsMouse ? 0.25 : 0.1)

                            Row {
                                id: pillRow
                                anchors.centerIn: parent
                                spacing: 10
                                Text {
                                    text: pill.modelData[0]
                                    font.family: root.fontFamily
                                    font.pixelSize: 16
                                    color: hover.containsMouse ? Colors.primary : Colors.onSurface
                                }
                                Text {
                                    text: pill.modelData[1]
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    color: Colors.onSurface
                                }
                            }

                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.power(pill.modelData[2])
                            }
                        }
                    }
                }
            }
        }
    }
}
