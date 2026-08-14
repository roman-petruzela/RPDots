import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

// Zamknout / restart / vypnout. Restart a vypnutí se nejdřív ptají —
// omylem trefené tlačítko by stálo rozdělanou práci.
Item {
    id: root

    implicitWidth: 340
    implicitHeight: 44 + (confirming !== "" ? 42 : 0)

    // id akce, na kterou se právě ptáme ("" = na nic)
    property string confirming: ""

    Process { id: lockProc;   command: ["swaylock"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: powerProc;  command: ["systemctl", "poweroff"] }

    readonly property var actions: [
        { id: "lock",   icon: "󰌾", label: "Lock",     accent: Colors.secondary,
          question: "" },
        { id: "reboot", icon: "󰜉", label: "Restart",  accent: Colors.tertiary,
          question: "Restart the computer?" },
        { id: "power",  icon: "󰐥", label: "Shut down", accent: Colors.errorColor,
          question: "Shut down the computer?" },
    ]

    function trigger(action) {
        if (action.question === "") {
            run(action.id)
            return
        }
        // druhé kliknutí na stejné tlačítko dotaz zase schová
        root.confirming = (root.confirming === action.id) ? "" : action.id
    }

    function run(id) {
        root.confirming = ""
        if (id === "lock")        lockProc.running = true
        else if (id === "reboot") rebootProc.running = true
        else if (id === "power")  powerProc.running = true
    }

    readonly property var pending:
        actions.find(a => a.id === root.confirming) || null

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            width: parent.width
            height: 44
            spacing: 8

            Repeater {
                model: root.actions

                Rectangle {
                    required property var modelData

                    width: (root.width - 16) / 3
                    height: 44
                    radius: 12

                    readonly property bool armed: root.confirming === modelData.id

                    color: (hover.containsMouse || armed)
                        ? Qt.rgba(Qt.color(modelData.accent).r,
                                  Qt.color(modelData.accent).g,
                                  Qt.color(modelData.accent).b, armed ? 0.30 : 0.18)
                        : Colors.surfaceContainerHigh
                    border.color: Qt.rgba(Qt.color(modelData.accent).r,
                                          Qt.color(modelData.accent).g,
                                          Qt.color(modelData.accent).b, armed ? 0.8 : 0.3)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                            color: modelData.accent
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                            color: Colors.onSurfaceVariant
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.trigger(modelData)
                    }
                }
            }
        }

        // ── Potvrzení ──────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 34
            radius: 10
            visible: root.pending !== null
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: root.pending
                ? Qt.rgba(Qt.color(root.pending.accent).r,
                          Qt.color(root.pending.accent).g,
                          Qt.color(root.pending.accent).b, 0.5)
                : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 132
                    elide: Text.ElideRight
                    text: root.pending ? root.pending.question : ""
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.onSurface
                }

                ConfirmBtn {
                    text: "Cancel"
                    accent: Colors.outline
                    onClicked: root.confirming = ""
                }
                ConfirmBtn {
                    text: "Yes"
                    accent: root.pending ? root.pending.accent : Colors.primary
                    onClicked: if (root.pending) root.run(root.pending.id)
                }
            }
        }
    }

    component ConfirmBtn: Rectangle {
        id: cb
        property string text: ""
        property color accent: Colors.primary
        signal clicked()

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 60; height: 24; radius: 8
        color: cbHover.containsMouse
            ? Qt.rgba(Qt.color(cb.accent).r, Qt.color(cb.accent).g, Qt.color(cb.accent).b, 0.25)
            : Colors.surfaceContainerHighest
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: cb.text
            font.pixelSize: 10
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.onSurface
        }

        MouseArea {
            id: cbHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked()
        }
    }
}
