import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import "Colors.js" as Colors

Item {
    id: root

    implicitWidth: 340
    implicitHeight: visible ? body.implicitHeight + 24 : 0
    visible: !!activePlayer

    readonly property var players: Mpris.players.values.filter(
        p => (p.dbusName || "").indexOf("playerctld") < 0)

    readonly property var activePlayer: {
        for (const p of players)
            if (p.playbackState === MprisPlaybackState.Playing) return p
        return players.length > 0 ? players[0] : null
    }

    readonly property string artUrl: {
        if (!activePlayer) return ""
        const direct = (activePlayer.trackArtUrl || "").toString()
        if (direct !== "") return direct
        const url = ((activePlayer.metadata || {})["xesam:url"] || "").toString()
        const id = url.match(/[?&]v=([\w-]{11})/) || url.match(/youtu\.be\/([\w-]{11})/)
        return id ? "https://img.youtube.com/vi/" + id[1] + "/hqdefault.jpg" : ""
    }

    readonly property bool hasArt: artUrl !== ""

    readonly property bool playing: !!activePlayer
        && activePlayer.playbackState === MprisPlaybackState.Playing

    readonly property real trackLen: activePlayer && activePlayer.lengthSupported
        ? (activePlayer.length || 0) : 0
    readonly property real trackPos: activePlayer && activePlayer.positionSupported
        ? (activePlayer.position || 0) : 0
    property real stickyLen: 0
    onTrackLenChanged: if (trackLen > 0) stickyLen = trackLen

    Connections {
        target: root.activePlayer
        function onTrackChanged() { root.stickyLen = 0 }
    }

    readonly property real effectiveLen: trackLen > 0 ? trackLen : stickyLen
    readonly property bool hasLength: effectiveLen > 0
    readonly property real trackProgress: hasLength
        ? Math.min(trackPos / effectiveLen, 1.0) : 0

    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
    }

    function fmtTime(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Colors.surfaceContainerHigh
        clip: true

        Column {
            id: body
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10

            Row {
                width: parent.width
                spacing: 12

                Item {
                    id: art
                    width: 56; height: 56
                    Rectangle {
                        id: artMask
                        anchors.fill: parent
                        radius: 10
                        visible: false
                        layer.enabled: true
                    }
                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(112, 112)
                        asynchronous: true
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: artImg
                        visible: root.hasArt && artImg.status === Image.Ready
                        maskEnabled: true
                        maskSource: artMask
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        visible: !root.hasArt || artImg.status !== Image.Ready
                        color: Qt.alpha(Colors.primary, 0.16)
                        Text {
                            anchors.centerIn: parent
                            text: "\u{f075a}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            color: Colors.primary
                        }
                    }
                }

                Column {
                    width: parent.width - art.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown") : ""
                        font.pixelSize: 13; font.weight: Font.DemiBold
                        font.family: "JetBrainsMono Nerd Font"
                        color: Colors.onSurface; elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.activePlayer
                            ? (root.activePlayer.trackArtist || root.activePlayer.identity || "") : ""
                        font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
                        color: Colors.onSurfaceVariant; elide: Text.ElideRight
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4

                Rectangle {
                    width: parent.width; height: 4; radius: 2
                    opacity: root.hasLength ? 1.0 : 0.45
                    color: Colors.surfaceContainerHighest

                    Rectangle {
                        width: parent.width * root.trackProgress
                        height: parent.height; radius: 2
                        color: Colors.primary
                        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -8
                        anchors.bottomMargin: -8
                        enabled: !!root.activePlayer && root.activePlayer.canSeek && root.hasLength
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: e => {
                            root.activePlayer.position =
                                Math.max(0, Math.min(1, e.x / width)) * root.trackLen
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: posLbl.implicitHeight
                    Text {
                        id: posLbl
                        text: root.fmtTime(root.trackPos)
                        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                        color: Colors.onSurfaceVariant
                    }
                    Text {
                        anchors.right: parent.right
                        text: root.hasLength ? root.fmtTime(root.effectiveLen) : "live"
                        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                        color: Colors.onSurfaceVariant
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                CtrlBtn {
                    icon: "\u{f04ae}"
                    enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
                    onClicked: root.activePlayer.previous()
                }
                CtrlBtn {
                    icon: root.playing ? "\u{f03e4}" : "\u{f040a}"
                    main: true
                    enabled: !!root.activePlayer && root.activePlayer.canTogglePlaying
                    onClicked: root.activePlayer.togglePlaying()
                }
                CtrlBtn {
                    icon: "\u{f04ad}"
                    enabled: !!root.activePlayer && root.activePlayer.canGoNext
                    onClicked: root.activePlayer.next()
                }
            }
        }
    }

    component CtrlBtn: Rectangle {
        id: btn
        property string icon: ""
        property bool main: false
        property bool enabled: true
        signal clicked()

        width: main ? 44 : 36; height: width; radius: width / 2
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        opacity: enabled ? 1.0 : 0.4
        color: main ? (ma.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary)
             : ma.containsMouse && enabled ? Colors.surfaceContainerHighest : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.pixelSize: btn.main ? 20 : 18
            font.family: "JetBrainsMono Nerd Font"
            color: btn.main ? Colors.onPrimary : Colors.onSurface
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
