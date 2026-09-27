import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import "Colors.js" as Colors

PanelWindow {
    id: root

    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive && flow !== null

    PolkitAgent { id: agent }

    visible: false
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rp-overlay"
    WlrLayershell.keyboardFocus: pop.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    PopAnim { id: pop; window: root; target: card }

    FocusedOutput { id: opener; window: root }

    onActiveChanged: {
        if (active) {
            input.text = ""
            if (!pop.cancelClose()) opener.show()
        } else {
            pop.dismiss()
        }
    }

    Connections {
        target: root.flow
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired) {
                input.text = ""
                input.forceActiveFocus()
            }
        }
    }

    function submit() {
        if (!flow || !flow.isResponseRequired) return
        flow.submit(input.text)
        input.text = ""
    }

    function cancel() {
        if (flow) flow.cancelAuthenticationRequest()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.scrim, 0.35 * card.opacity)
        MouseArea { anchors.fill: parent }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 440
        height: col.implicitHeight + 56
        radius: 22
        color: Qt.alpha(Colors.surfaceContainer, 0.96)
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.8)

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 28 }
            spacing: 14

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56; height: 56; radius: 28
                color: Qt.alpha(Colors.primary, 0.14)
                Text {
                    anchors.centerIn: parent
                    text: "󰌾"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 26
                    color: Colors.primary
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Authentication required"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: Colors.onSurface
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.flow?.message ?? ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Colors.onSurfaceVariant
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "as " + (root.flow?.selectedIdentity?.displayName ?? Quickshell.env("USER"))
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: Colors.outline
            }

            Rectangle {
                width: parent.width
                height: 42
                radius: 12
                color: Colors.surfaceContainerHighest
                border.width: 1
                border.color: root.flow?.supplementaryIsError ? Colors.errorColor
                    : input.activeFocus ? Colors.primary : Colors.outlineVariant

                TextInput {
                    id: input
                    anchors { left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    focus: pop.shown
                    enabled: root.flow?.isResponseRequired ?? false
                    echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Colors.onSurface
                    selectionColor: Qt.alpha(Colors.primary, 0.4)
                    clip: true
                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onEscapePressed: root.cancel()

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                        font: input.font
                        color: Colors.outline
                    }
                }
            }

            Text {
                visible: text !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.flow?.supplementaryMessage ?? ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: root.flow?.supplementaryIsError ? Colors.errorColor : Colors.onSurfaceVariant
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.flow?.actionId ?? ""
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 10
                color: Colors.outline
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Repeater {
                    model: [
                        { id: "cancel", label: "Cancel", primary: false },
                        { id: "ok", label: "Authenticate", primary: true },
                    ]
                    Rectangle {
                        required property var modelData
                        width: 150
                        height: 38
                        radius: 12
                        color: modelData.primary
                            ? (btnHover.hovered ? Qt.lighter(Colors.primary, 1.1) : Colors.primary)
                            : (btnHover.hovered ? Qt.alpha(Colors.onSurface, 0.08) : "transparent")
                        border.width: modelData.primary ? 0 : 1
                        border.color: Colors.outlineVariant
                        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: modelData.id === "ok" ? root.submit() : root.cancel() }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: modelData.primary ? Font.DemiBold : Font.Normal
                            color: modelData.primary ? Colors.onPrimary : Colors.onSurface
                        }
                    }
                }
            }
        }
    }
}
