import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "Colors.js" as Colors

PanelWindow {
    id: barWindow
    color: "transparent"

    // Provided by Variants in shell.qml
    property var modelData: null
    screen: modelData

    anchors { left: true; right: true; top: true }
    implicitHeight: 40
    margins { left: 0; right: 0; top: 0 }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Auto

    // ── Niri state via persistent event-stream ───────────────
    property var  niriWorkspaces: []
    property string niriFocusedTitle: ""

    // Initial workspace fetch so dots show before first WorkspacesChanged
    Process {
        id: wsInit
        command: ["niri", "msg", "--json", "workspaces"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var arr = JSON.parse(data)
                    if (Array.isArray(arr))
                        barWindow.niriWorkspaces = arr
                } catch(e) {}
            }
        }
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var ev = JSON.parse(data)

                    if (ev.WorkspacesChanged) {
                        barWindow.niriWorkspaces = ev.WorkspacesChanged.workspaces || []
                    }
                    if (ev.WindowFocusChanged) {
                        var w = ev.WindowFocusChanged.window
                        barWindow.niriFocusedTitle = w ? (w.title || "") : ""
                    }
                    if (ev.WindowsChanged) {
                        var wins = ev.WindowsChanged.windows || []
                        for (var i = 0; i < wins.length; i++) {
                            if (wins[i].is_focused) {
                                barWindow.niriFocusedTitle = wins[i].title || ""
                                break
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // Restart event-stream if it dies
    Timer {
        interval: 3000; repeat: true; running: !eventStream.running
        onTriggered: eventStream.running = true
    }

    // Fallback workspace poll — ensures dots update even if Repeater
    // doesn't re-render on var array reference change alone
    Timer {
        interval: 800; repeat: true; running: true
        onTriggered: { wsInit.running = false; wsInit.running = true }
    }

    Rectangle {
        id: barBg
        anchors.fill: parent
        color: Qt.rgba(Qt.color(Colors.surfaceContainer).r,
                       Qt.color(Colors.surfaceContainer).g,
                       Qt.color(Colors.surfaceContainer).b, 0.65)

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Qt.rgba(Qt.color(Colors.primary).r, Qt.color(Colors.primary).g, Qt.color(Colors.primary).b, 0.42)
        }

        // ── LEFT ─────────────────────────────────────────────
        Row {
            id: leftSection
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            height: parent.height
            spacing: 6

            Rectangle {
                height: 26
                width: workspaces.implicitWidth + 6
                radius: 13
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(Qt.color(Colors.surfaceContainerHigh).r,
                               Qt.color(Colors.surfaceContainerHigh).g,
                               Qt.color(Colors.surfaceContainerHigh).b, 0.72)

                BarWorkspaces {
                    id: workspaces
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    workspaces: barWindow.niriWorkspaces
                    screenOutput: barWindow.modelData ? barWindow.modelData.name : ""
                }
            }

            BarWindowTitle {
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                title: barWindow.niriFocusedTitle
            }
        }

        // ── CENTER: clock pinned at exact screen midpoint ────
        Rectangle {
            id: clockPill
            height: 28
            width: clock.implicitWidth + 4
            radius: 14
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            color: Qt.rgba(Qt.color(Colors.primaryContainer).r,
                           Qt.color(Colors.primaryContainer).g,
                           Qt.color(Colors.primaryContainer).b, 0.50)
            border { color: Qt.rgba(Qt.color(Colors.primary).r, Qt.color(Colors.primary).g, Qt.color(Colors.primary).b, 0.32); width: 1 }

            BarClock {
                id: clock
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
            }
        }

        // ── CENTER-LEFT: [media] ─── [cava] ─── [clock] ─────
        Row {
            id: centerLeft
            anchors { right: clockPill.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
            height: parent.height
            spacing: 14

            BarMedia {
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
            }

            BarCava {
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
            }
        }

        // ── RIGHT ────────────────────────────────────────────
        Row {
            id: rightSection
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            height: parent.height
            spacing: 0

            BarNetwork  {
                id: barNet
                anchors.verticalCenter: parent.verticalCenter; height: parent.height
                screen: barWindow.modelData
                // leftEdge of BarNetwork in screen coords = rightSection.x + barNet.x (barNet.x=0, first in row)
                popupLeftMargin: Math.max(4, rightSection.x + barNet.x)
            }
            BarSep {}
            BarSysStats { anchors.verticalCenter: parent.verticalCenter; height: parent.height }
            BarSep {}
            BarAudio    { anchors.verticalCenter: parent.verticalCenter; height: parent.height }
            BarBattery  { anchors.verticalCenter: parent.verticalCenter; height: parent.height }
            BarBrightness { anchors.verticalCenter: parent.verticalCenter; height: parent.height }
            BarSep {}
            BarTray     {
                id: barTray
                anchors.verticalCenter: parent.verticalCenter; height: parent.height
                screen: barWindow.modelData
                // rightEdge of tray button in screen coords; popup anchored right so margin = distance from right edge
                popupRightMargin: Math.max(4, barBg.width - (rightSection.x + barTray.x + barTray.implicitWidth))
            }
            BarSep {}
            BarPower    { anchors.verticalCenter: parent.verticalCenter; height: parent.height }
        }
    }

    component BarSep: Rectangle {
        width: 1; height: 18
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Qt.rgba(Qt.color(Colors.outlineVariant).r,
                       Qt.color(Colors.outlineVariant).g,
                       Qt.color(Colors.outlineVariant).b, 0.40)
    }
}
