import Quickshell
import QtQuick
import QtQuick.Effects
import "../Colors.js" as Colors

Item {
    id: content
    required property var host
    property string wallpaper: Quickshell.env("HOME") + "/.local/share/wallpapers/current"
    property string backdrop: ""
    readonly property string fontFamily: host.fontFamily

    function shortLayout(name) {
        if (name.startsWith("Czech")) return "CZ"
        if (name.startsWith("English")) return "US"
        return name.slice(0, 2).toUpperCase()
    }

    Keys.onPressed: event => {
        const h = content.host
        if (h.unlocking) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            h.submit()
        } else if (event.key === Qt.Key_Escape) {
            if (!h.busy) { h.password = ""; h.message = "" }
        } else if (event.key === Qt.Key_Backspace) {
            if (!h.busy) h.password = (event.modifiers & Qt.ControlModifier) ? "" : h.password.slice(0, -1)
        } else if (event.text.length > 0 && event.text >= " " && !h.busy) {
            h.password += event.text
            h.message = ""
        } else {
            return
        }
        event.accepted = true
    }

    Image {
        id: wall
        anchors.fill: parent
        source: "file://" + (content.backdrop !== "" ? content.backdrop : content.wallpaper)
        fillMode: Image.PreserveAspectCrop
        cache: false
        onStatusChanged: if (status === Image.Error && content.backdrop !== "") content.backdrop = ""
        visible: false
    }
    MultiEffect {
        id: blurFx
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 0
        blurMax: 64
        saturation: 0.1
    }
    Rectangle {
        id: shade
        anchors.fill: parent
        opacity: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Colors.background, 0.35) }
            GradientStop { position: 0.55; color: Qt.alpha(Colors.background, 0.45) }
            GradientStop { position: 1.0; color: Qt.alpha(Colors.background, 0.8) }
        }
    }

    Item {
        id: ui
        anchors.fill: parent
        transformOrigin: Item.Center

        Column {
            id: clockCol
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.12)
            spacing: 6
            opacity: 0
            transform: Translate { id: clockShift; y: -18 }

            Text {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: content.fontFamily
                font.pixelSize: 88
                font.weight: Font.Light
                color: Colors.onSurface
            }
            Text {
                id: date
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: content.fontFamily
                font.pixelSize: 17
                color: Colors.onSurfaceVariant
            }
            Timer {
                running: content.visible
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

        Column {
            id: formCol
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 30
            spacing: 14
            opacity: 0
            transform: Translate { id: formShift; y: 14 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Quickshell.env("USER") ?? ""
                font.family: content.fontFamily
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
                border.color: content.host.message !== "" ? Colors.errorColor
                    : content.host.busy && !content.host.unlocking ? Qt.alpha(Colors.primary, 0.5)
                    : Colors.primary
                Behavior on border.color { ColorAnimation { duration: 160 } }

                property real shake: 0
                transform: Translate { x: field.shake }
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: field; property: "shake"; to: -10; duration: 45 }
                    NumberAnimation { target: field; property: "shake"; to: 9; duration: 70 }
                    NumberAnimation { target: field; property: "shake"; to: -6; duration: 60 }
                    NumberAnimation { target: field; property: "shake"; to: 0; duration: 50 }
                }
                Connections {
                    target: content.host
                    function onFailuresChanged() { shakeAnim.restart() }
                }

                Text {
                    anchors { left: parent.left; leftMargin: 26; verticalCenter: parent.verticalCenter }
                    visible: content.host.password === ""
                    text: "Password"
                    font.family: content.fontFamily
                    font.pixelSize: 16
                    color: Qt.alpha(Colors.onSurfaceVariant, 0.7)
                }

                Item {
                    anchors { left: parent.left; leftMargin: 26; right: layoutChip.left
                              rightMargin: 12; top: parent.top; bottom: parent.bottom }
                    clip: true

                    Row {
                        id: dots
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: width > parent.width ? parent.right : undefined
                        spacing: 7

                        SequentialAnimation on opacity {
                            running: content.host.busy && !content.host.unlocking
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.35; duration: 420; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
                        }

                        Repeater {
                            model: content.host.password.length
                            Rectangle {
                                width: 9; height: 9; radius: 4.5
                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                color: content.host.unlocking ? Colors.primary : Colors.onSurface
                                Behavior on color { ColorAnimation { duration: 160 } }
                                scale: 0.3
                                Component.onCompleted: pop.start()
                                NumberAnimation on scale {
                                    id: pop
                                    running: false
                                    to: 1
                                    duration: 140
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2.2
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: layoutChip
                    visible: content.host.layout !== ""
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 44
                    height: 34
                    radius: 17
                    color: Qt.alpha(Colors.primaryContainer, 0.9)
                    Text {
                        anchors.centerIn: parent
                        text: content.shortLayout(content.host.layout)
                        font.family: content.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Colors.onPrimaryContainer
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
                            content.host.refreshLayout()
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: field.width
                height: 20
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: content.host.message
                font.family: content.fontFamily
                font.pixelSize: 14
                color: Colors.errorColor
            }
        }

        Row {
            id: powerRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            spacing: 12
            opacity: 0

            Repeater {
                model: [["\u{f04b2}", "Suspend", "suspend"],
                        ["\u{f0709}", "Restart", "reboot"],
                        ["\u{f0425}", "Shut down", "poweroff"]]

                Rectangle {
                    id: pill
                    required property var modelData
                    width: pillRow.implicitWidth + 36
                    height: 44
                    radius: 22
                    color: hover.containsMouse ? Qt.alpha(Colors.surfaceContainerHighest, 0.9)
                                               : Qt.alpha(Colors.surfaceContainer, 0.6)
                    border.width: 1
                    border.color: Qt.alpha(Colors.onSurface, hover.containsMouse ? 0.25 : 0.1)

                    Row {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            text: pill.modelData[0]
                            font.family: content.fontFamily
                            font.pixelSize: 16
                            color: hover.containsMouse ? Colors.primary : Colors.onSurface
                        }
                        Text {
                            text: pill.modelData[1]
                            font.family: content.fontFamily
                            font.pixelSize: 14
                            color: Colors.onSurface
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["systemctl", pill.modelData[2]])
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: enterAnim
        running: true
        NumberAnimation { target: blurFx; property: "blur"; to: 1; duration: 700; easing.type: Easing.OutCubic }
        NumberAnimation { target: shade; property: "opacity"; to: 1; duration: 600; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            ParallelAnimation {
                NumberAnimation { target: clockCol; property: "opacity"; to: 1; duration: 520; easing.type: Easing.OutQuint }
                NumberAnimation { target: clockShift; property: "y"; to: 0; duration: 520; easing.type: Easing.OutQuint }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 240 }
            ParallelAnimation {
                NumberAnimation { target: formCol; property: "opacity"; to: 1; duration: 520; easing.type: Easing.OutQuint }
                NumberAnimation { target: formShift; property: "y"; to: 0; duration: 520; easing.type: Easing.OutQuint }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 360 }
            NumberAnimation { target: powerRow; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
        }
    }

    ParallelAnimation {
        id: exitAnim
        running: content.host.unlocking
        SequentialAnimation {
            PauseAnimation { duration: 90 }
            ParallelAnimation {
                NumberAnimation { target: ui; property: "opacity"; to: 0; duration: 240; easing.type: Easing.InCubic }
                NumberAnimation { target: ui; property: "scale"; to: 0.97; duration: 240; easing.type: Easing.InCubic }
            }
        }
        NumberAnimation { target: blurFx; property: "blur"; to: 0; duration: 380; easing.type: Easing.InOutCubic }
        NumberAnimation { target: shade; property: "opacity"; to: 0; duration: 380; easing.type: Easing.InOutCubic }
    }
}
