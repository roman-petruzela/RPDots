import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import "../Colors.js" as Colors

Rectangle {
    id: card

    required property var notif
    required property var service
    property bool popup: false
    property int timeoutSec: 6
    readonly property bool critical: notif && notif.urgency === NotificationUrgency.Critical
    readonly property int lifetime: !popup || critical ? 0
        : notif.expireTimeout > 0 ? notif.expireTimeout : timeoutSec * 1000
    property bool leaving: false
    property real created: Date.now()

    signal expired()

    implicitHeight: content.implicitHeight + 24 + (lifetime > 0 ? 4 : 0)
    radius: 16
    color: popup ? Qt.alpha(Colors.surfaceContainer, 0.94)
         : hover.hovered ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
    border.width: popup || critical ? 1 : 0
    border.color: critical ? Colors.errorColor : Colors.outlineVariant
    clip: true
    Behavior on color { ColorAnimation { duration: 120 } }

    opacity: leaving ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 160 } }

    function leave() {
        if (leaving) return
        leaving = true
        leaveTimer.start()
    }
    Timer { id: leaveTimer; interval: 170; onTriggered: card.expired() }

    Timer {
        id: life
        interval: card.lifetime
        running: card.lifetime > 0 && !hover.hovered && !card.leaving
        onTriggered: card.leave()
    }
    property real progress: 1
    NumberAnimation on progress {
        id: bar
        running: card.lifetime > 0
        paused: hover.hovered
        from: 1; to: 0
        duration: card.lifetime
    }
    onLifetimeChanged: if (lifetime > 0) { progress = 1; bar.restart() }

    HoverHandler { id: hover }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: card.service.activate(card.notif)
    }
    TapHandler {
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        onTapped: card.notif.dismiss()
    }

    Row {
        id: content
        x: 14; y: 12
        width: card.width - 28
        spacing: 12

        Item {
            id: iconBox
            width: 36; height: 36
            readonly property string img: card.notif ? (card.notif.image || "") : ""
            readonly property string appIcon: {
                if (!card.notif) return ""
                const a = card.notif.appIcon || ""
                if (a.startsWith("/") || a.startsWith("file:")) return a.startsWith("/") ? "file://" + a : a
                return Quickshell.iconPath(a || card.notif.desktopEntry || "", true)
            }
            Image {
                id: pic
                anchors.fill: parent
                visible: iconBox.img !== ""
                source: iconBox.img
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(72, 72)
                asynchronous: true
                layer.enabled: true
            }
            IconImage {
                anchors.fill: parent
                visible: iconBox.img === "" && iconBox.appIcon !== ""
                source: iconBox.appIcon
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                visible: iconBox.img === "" && iconBox.appIcon === ""
                radius: 10
                color: Qt.alpha(Colors.primary, 0.16)
                Text {
                    anchors.centerIn: parent
                    text: "\u{f009a}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: Colors.primary
                }
            }
        }

        Column {
            width: content.width - iconBox.width - content.spacing
            spacing: 3

            Item {
                width: parent.width
                height: appLine.implicitHeight
                Text {
                    id: appLine
                    anchors { left: parent.left; right: closeBtn.left; rightMargin: 8 }
                    text: (card.notif ? card.notif.appName : "") || "Notification"
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: card.critical ? Colors.errorColor : Colors.onSurfaceVariant
                }
                Text {
                    id: closeBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "\u{f0156}"
                    opacity: hover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: closeArea.containsMouse ? Colors.primary : Colors.onSurfaceVariant
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.notif.dismiss()
                    }
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: card.notif ? card.notif.summary : ""
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Colors.onSurface
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: card.notif ? card.notif.body : ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 3
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: Colors.onSurfaceVariant
                linkColor: Colors.primary
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                width: parent.width
                spacing: 6
                topPadding: visible ? 6 : 0
                visible: actionRep.count > 0
                Repeater {
                    id: actionRep
                    model: card.notif ? Array.from(card.notif.actions).filter(a => a.identifier !== "default" && a.text !== "") : []
                    Rectangle {
                        required property var modelData
                        width: actionText.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: actArea.containsMouse ? Colors.primaryContainer : Qt.alpha(Colors.surfaceContainerHighest, 0.9)
                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: actArea.containsMouse ? Colors.onPrimaryContainer : Colors.onSurface
                        }
                        MouseArea {
                            id: actArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                parent.modelData.invoke()
                                if (!card.notif.resident) card.notif.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        visible: card.lifetime > 0
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 14; bottomMargin: 5 }
        width: (card.width - 28) * card.progress
        height: 2
        radius: 1
        color: Qt.alpha(Colors.primary, 0.6)
    }
}
