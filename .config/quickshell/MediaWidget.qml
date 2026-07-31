import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: visible ? (hasArt ? 182 : 96) : 0
    visible: !!activePlayer

    property var activePlayer: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property bool hasArt: activePlayer
        && activePlayer.trackArtUrl
        && activePlayer.trackArtUrl.toString() !== ""
    property real trackProgress: 0.0
    property int  trackPos: 0
    property int  trackLen: 0

    function fmtTime(us) {
        var s = Math.floor(us / 1000000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Timer {
        interval: 1000
        running: !!activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: {
            if (!activePlayer) return
            trackLen = activePlayer.trackLength || 0
            trackPos = activePlayer.trackPosition || 0
            trackProgress = trackLen > 0 ? Math.min(trackPos / trackLen, 1.0) : 0
        }
    }

    Connections {
        target: activePlayer
        function onTrackTitleChanged() { trackProgress = 0; trackPos = 0 }
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(Qt.color(Colors.surfaceContainerHigh).r,
                       Qt.color(Colors.surfaceContainerHigh).g,
                       Qt.color(Colors.surfaceContainerHigh).b, 0.92)
        border.color: Colors.outlineVariant
        border.width: 1
        clip: true

        // Full-width album art banner
        Rectangle {
            id: artBanner
            visible: hasArt
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: visible ? 120 : 0
            color: Colors.surfaceContainer

            Image {
                anchors.fill: parent
                source: hasArt ? activePlayer.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
            }

            // Bottom gradient over art
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 72
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(Qt.color(Colors.surfaceContainerHigh).r,
                                       Qt.color(Colors.surfaceContainerHigh).g,
                                       Qt.color(Colors.surfaceContainerHigh).b, 0.95)
                    }
                }
            }

            // Track info overlaid on gradient
            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.bottomMargin: 10
                spacing: 1

                Text {
                    width: parent.width
                    text: activePlayer ? (activePlayer.trackTitle || "Unknown") : ""
                    font.pixelSize: 14
                    font.weight: Font.SemiBold
                    color: Colors.onSurface
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: activePlayer ? (activePlayer.trackArtist || activePlayer.identity || "") : ""
                    font.pixelSize: 12
                    color: Colors.onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        // Controls + progress section
        Column {
            anchors {
                left: parent.left; right: parent.right
                top: artBanner.bottom
                leftMargin: 14; rightMargin: 14; topMargin: 10; bottomMargin: 12
            }
            spacing: 8

            // Track info when no art
            Column {
                visible: !hasArt
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: activePlayer ? (activePlayer.trackTitle || "Unknown") : ""
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Colors.onSurface
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: activePlayer ? (activePlayer.trackArtist || activePlayer.identity || "") : ""
                    font.pixelSize: 12
                    color: Colors.onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Progress bar + time
            Column {
                width: parent.width
                spacing: 4

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
                        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
                    }
                }

                Row {
                    width: parent.width

                    Text {
                        text: fmtTime(trackPos)
                        font.pixelSize: 10
                        font.family: "JetBrains Mono"
                        color: Colors.outline
                    }
                    Item { width: parent.width - 2 * 36; height: 1 }
                    Text {
                        text: trackLen > 0 ? fmtTime(trackLen) : ""
                        font.pixelSize: 10
                        font.family: "JetBrains Mono"
                        color: Colors.outline
                    }
                }
            }

            // Controls
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                MediaButton {
                    icon: "⏮"
                    onClicked: if (activePlayer) activePlayer.previous()
                }
                MediaButton {
                    icon: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"
                    size: 34
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
