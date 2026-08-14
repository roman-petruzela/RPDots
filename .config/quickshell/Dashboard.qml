import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "Colors.js" as Colors

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    // Okno drží celou plochu, aby se dalo zavřít kliknutím kamkoliv mimo panel.
    // Panel samotný zůstává 380 px vpravo.
    anchors { left: true; right: true; top: true; bottom: true }

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: Region { item: panel }

    property real slideX: 380

    Behavior on slideX {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    onVisibleChanged: {
        if (visible) {
            slideX = 0
        } else {
            slideX = 380
            scroll.contentY = 0
        }
    }

    // U více monitorů vyjede na tom, na kterém zrovna pracuješ.
    FocusedOutput { id: opener; window: root }

    function open()   { opener.show() }
    function toggle() { if (root.visible) root.visible = false; else root.open() }

    // Zavření kliknutím mimo panel
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.visible = false
    }

    Rectangle {
        id: panel
        x: parent.width - width + slideX
        y: 0
        width: 380
        height: parent.height

        color: Qt.rgba(Qt.color(Colors.surfaceContainer).r,
                       Qt.color(Colors.surfaceContainer).g,
                       Qt.color(Colors.surfaceContainer).b, 0.90)

        // Left border
        Rectangle {
            x: 0; y: 0; width: 1; height: parent.height
            color: Colors.outlineVariant
            opacity: 0.5
        }

        MouseArea { anchors.fill: parent }

        // Content with fade-in
        Item {
            anchors.fill: parent
            opacity: 1.0 - (slideX / 380) * 0.4

            Flickable {
                id: scroll
                anchors {
                    fill: parent
                    topMargin: 20
                    bottomMargin: 16
                    leftMargin: 20
                    rightMargin: 20
                }
                contentHeight: col.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: col
                    width: parent.width
                    spacing: 0

                    // ── Clock ──────────────────────────────────────
                    ClockWidget { width: parent.width }

                    Item { width: parent.width; height: 12 }

                    // ── Network ────────────────────────────────────
                    NetworkWidget { width: parent.width }

                    Item { width: parent.width; height: 20 }
                    Divider { width: parent.width }
                    Item { width: parent.width; height: 16 }

                    // ── System ─────────────────────────────────────
                    SectionLabel { title: "System" }
                    Item { width: parent.width; height: 10 }
                    SystemWidget { width: parent.width }

                    Item { width: parent.width; height: 16 }
                    Divider { width: parent.width; visible: mediaWidget.visible }
                    Item { width: parent.width; height: mediaWidget.visible ? 16 : 0; visible: mediaWidget.visible }

                    // ── Media ──────────────────────────────────────
                    SectionLabel { title: "Now Playing"; visible: mediaWidget.visible }
                    Item { width: parent.width; height: mediaWidget.visible ? 10 : 0; visible: mediaWidget.visible }
                    MediaWidget { id: mediaWidget; width: parent.width }

                    Item { width: parent.width; height: 16 }
                    Divider { width: parent.width }
                    Item { width: parent.width; height: 16 }

                    // ── Calendar ───────────────────────────────────
                    SectionLabel { title: "Calendar" }
                    Item { width: parent.width; height: 10 }
                    CalendarWidget { width: parent.width }

                    Item { width: parent.width; height: 16 }
                    Divider { width: parent.width }
                    Item { width: parent.width; height: 14 }

                    // ── Quick Actions ──────────────────────────────
                    QuickActionsWidget { id: quickActions; width: parent.width }

                    Item { width: parent.width; height: 8 }
                }
            }
        }
    }
}
