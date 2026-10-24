import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import "Colors.js" as Colors

Item {
    id: root

    implicitWidth: 340
    implicitHeight: visible ? body.implicitHeight + 28 : 0
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

    readonly property bool hasArt: artUrl !== "" && artImg.status === Image.Ready

    readonly property bool playing: !!activePlayer
        && activePlayer.playbackState === MprisPlaybackState.Playing

    readonly property real trackLen: activePlayer && activePlayer.lengthSupported
        ? (activePlayer.length || 0) : 0
    readonly property real playerPos: activePlayer && activePlayer.positionSupported
        ? (activePlayer.position || 0) : 0
    property real stickyLen: 0
    onTrackLenChanged: if (trackLen > 0) stickyLen = trackLen

    property real seekPos: -1
    Timer { id: seekHold; interval: 1500; onTriggered: root.seekPos = -1 }
    onPlayerPosChanged: if (seekPos >= 0 && Math.abs(playerPos - seekPos) < 1.5) { seekPos = -1; seekHold.stop() }

    Connections {
        target: root.activePlayer
        function onTrackChanged() { root.stickyLen = 0; root.seekPos = -1 }
    }

    readonly property real effectiveLen: trackLen > 0 ? trackLen : stickyLen
    readonly property bool hasLength: effectiveLen > 0
    readonly property bool canSeek: !!activePlayer && activePlayer.canSeek && hasLength
    readonly property real trackPos: seek.pressed ? seek.previewPos : seekPos >= 0 ? seekPos : playerPos
    readonly property real trackProgress: hasLength ? Math.max(0, Math.min(trackPos / effectiveLen, 1)) : 0

    function seekTo(sec) {
        if (!canSeek) return
        seekPos = sec
        seekHold.restart()
        activePlayer.position = sec
    }

    Timer {
        interval: 500
        repeat: true
        running: root.playing && root.visible
        onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
    }

    function fmtTime(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    Item {
        id: blurred
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Image {
            id: artImg
            anchors { fill: parent; margins: -24 }
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 480
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: artImg
            source: artImg
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 0.6
            blurMax: 32
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: Colors.surfaceContainerHigh
    }

    Rectangle {
        id: cardMask
        anchors.fill: parent
        radius: card.radius
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: blurred
        visible: root.hasArt
        maskEnabled: true
        maskSource: cardMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        visible: root.hasArt
        color: Qt.alpha(Colors.surfaceContainerHigh, 0.55)
    }

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.5)
    }

    Column {
        id: body
        x: 14; y: 14
        width: parent.width - 28
        spacing: 14

        Item {
            width: parent.width
            height: 56

            Column {
                anchors { left: parent.left; leftMargin: 4; right: controls.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text {
                    width: parent.width
                    text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown track") : ""
                    font.pixelSize: 14; font.weight: Font.DemiBold
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

            Row {
                id: controls
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2

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

        Item {
            id: bar
            width: parent.width
            height: 32

            readonly property real minFill: posLbl.implicitWidth + 24
            readonly property real fillWidth: minFill + (width - minFill) * root.trackProgress

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(Colors.surfaceContainerHighest, 0.85)
                opacity: root.hasLength ? 1 : 0.5
            }
            Rectangle {
                height: parent.height
                width: bar.fillWidth
                radius: height / 2
                color: Colors.primary
            }
            Text {
                id: posLbl
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: root.fmtTime(root.trackPos)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11; font.weight: Font.Medium
                color: Colors.onPrimary
            }
            Text {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: root.hasLength ? root.fmtTime(root.effectiveLen) : "live"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: bar.fillWidth > bar.width - implicitWidth - 16 ? Colors.onPrimary : Colors.onSurfaceVariant
            }

            MouseArea {
                id: seek
                anchors.fill: parent
                enabled: root.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                property real previewPos: 0
                function pick(x) {
                    return Math.max(0, Math.min(1, (x - bar.minFill) / (width - bar.minFill))) * root.effectiveLen
                }
                onPressed: e => previewPos = pick(e.x)
                onPositionChanged: e => previewPos = pick(e.x)
                onReleased: root.seekTo(previewPos)
            }
        }
    }

    component CtrlBtn: Rectangle {
        id: btn
        property string icon: ""
        property bool main: false
        property bool enabled: true
        signal clicked()

        width: main ? 40 : 32; height: width; radius: width / 2
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        opacity: enabled ? 1.0 : 0.35
        color: main ? (ma.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary)
             : ma.containsMouse && enabled ? Qt.alpha(Colors.onSurface, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.pixelSize: btn.main ? 18 : 16
            font.family: "JetBrainsMono Nerd Font Propo"
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
