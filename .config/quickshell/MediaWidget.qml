import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: activePlayer ? (hasArt ? 110 : 88) : 0
    visible: !!activePlayer

    property var activePlayer: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property bool hasArt: activePlayer && activePlayer.trackArtUrl && activePlayer.trackArtUrl.toString() !== ""
    property real trackProgress: 0.0

    Timer {
        interval: 1000
        running: !!activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: {
            if (activePlayer && activePlayer.trackLength > 0)
                trackProgress = Math.min(activePlayer.trackPosition / activePlayer.trackLength, 1.0)
        }
    }

    Connections {
        target: activePlayer
        function onTrackTitleChanged() { trackProgress = 0 }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(
            Qt.color(Colors.surfaceContainerHigh).r,
            Qt.color(Colors.surfaceContainerHigh).g,
            Qt.color(Colors.surfaceContainerHigh).b,
            0.9
        )
        border.color: Colors.outlineVariant
        border.width: 1
        clip: true

        // Album art strip on left if available
        Rectangle {
            id: artStrip
            visible: hasArt
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: visible ? 80 : 0
            color: "transparent"

            Image {
                anchors.fill: parent
                source: hasArt ? activePlayer.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            // gradient fade to right
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: 32
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(
                            Qt.color(Colors.surfaceContainerHigh).r,
                            Qt.color(Colors.surfaceContainerHigh).g,
                            Qt.color(Colors.surfaceContainerHigh).b,
                            0.9
                        )
                    }
                }
            }
        }

        Column {
            anchors {
                left: artStrip.right
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                leftMargin: hasArt ? 4 : 14
                rightMargin: 14
                topMargin: 14
                bottomMargin: 10
            }
            spacing: 8

            Row {
                width: parent.width
                spacing: 8

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - controlRow.width - 8
                    spacing: 2

                    Text {
                        width: parent.width
                        text: activePlayer ? (activePlayer.trackTitle || "Neznámý titul") : ""
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Colors.onSurface
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: activePlayer ? (activePlayer.trackArtist || activePlayer.identity || "") : ""
                        font.pixelSize: 11
                        color: Colors.onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: controlRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    MediaButton {
                        icon: "⏮"
                        onClicked: if (activePlayer) activePlayer.previous()
                    }

                    MediaButton {
                        icon: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"
                        size: 32
                        onClicked: if (activePlayer) activePlayer.togglePlaying()
                    }

                    MediaButton {
                        icon: "⏭"
                        onClicked: if (activePlayer) activePlayer.next()
                    }
                }
            }

            // Progress bar
            Rectangle {
                width: parent.width
                height: 3
                radius: 2
                color: Colors.outlineVariant

                Rectangle {
                    width: parent.width * trackProgress
                    height: parent.height
                    radius: 2
                    color: Colors.primary

                    Behavior on width {
                        NumberAnimation { duration: 800; easing.type: Easing.Linear }
                    }
                }
            }
        }
    }
}
