import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: 80
    visible: !!activePlayer

    property var activePlayer: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Colors.surfaceContainerHigh
        border.color: Colors.outlineVariant
        border.width: 1

        Row {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 12

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 100
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
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                MediaButton {
                    icon: "⏮"
                    onClicked: if (activePlayer) activePlayer.previous()
                }

                MediaButton {
                    icon: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"
                    onClicked: if (activePlayer) activePlayer.togglePlaying()
                }

                MediaButton {
                    icon: "⏭"
                    onClicked: if (activePlayer) activePlayer.next()
                }
            }
        }
    }
}
