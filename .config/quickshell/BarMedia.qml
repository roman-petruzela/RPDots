import Quickshell.Services.Mpris
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: visible ? contentRow.implicitWidth + 4 : 0
    implicitHeight: parent ? parent.height : 40
    visible: !!player

    property var player: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property bool playing: player && player.playbackState === MprisPlaybackState.Playing

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.playing ? "" : ""
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.primary
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.player) root.player.togglePlaying()
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -1

            Text {
                width: Math.min(implicitWidth, 150)
                text: root.player ? (root.player.trackTitle || "") : ""
                font.pixelSize: 12
                font.weight: Font.Medium
                font.family: "JetBrainsMono Nerd Font"
                color: Colors.onSurface
                elide: Text.ElideRight
            }
            Text {
                width: Math.min(implicitWidth, 150)
                text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.55)
                elide: Text.ElideRight
            }
        }
    }
}
