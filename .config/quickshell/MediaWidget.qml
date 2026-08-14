import Quickshell.Services.Mpris
import QtQuick
import "Colors.js" as Colors

// Now Playing.
//
// Dvě věci, o které se to dřív rozbíjelo:
//  * vlastnosti se jmenují position/length (v sekundách), ne trackPosition
//    a trackLength — ty neexistují, takže čas i progressbar stály na nule,
//  * na sběrnici visí i proxy playerctld, která hlásí NoActivePlayer; když
//    padla volba na ni, tlačítka nedělala nic. Skutečný přehrávač má přednost.
Item {
    id: root

    implicitWidth: 340
    implicitHeight: visible ? (hasArt ? 190 : 104) : 0
    visible: !!activePlayer

    readonly property var players: Mpris.players.values.filter(
        p => (p.dbusName || "").indexOf("playerctld") < 0)

    // Proxy se nebere ani jako záloha: po zavření přehrávače na ní zůstane
    // viset poslední stopa, takže by widget dál ukazoval hudbu, která nehraje,
    // a tlačítka by šla do prázdna.
    readonly property var activePlayer: {
        for (const p of players)
            if (p.playbackState === MprisPlaybackState.Playing) return p
        return players.length > 0 ? players[0] : null
    }

    readonly property string artUrl: {
        if (!activePlayer) return ""
        const direct = (activePlayer.trackArtUrl || "").toString()
        if (direct !== "") return direct
        // Firefox u YouTube neposílá mpris:artUrl, ale posílá adresu videa —
        // náhled se z ní dá složit.
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
    // Firefox mpris:length nevysílá vůbec (lengthSupported je false) a quickshell
    // pak za délku vydává pozici — podíl by vycházel pořád 1.0.
    //
    // Délka se drží do konce stopy: kdyby ji přehrávač na okamžik nehlásil,
    // proužek by bez toho poskočil na prázdno a zase zpátky.
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

    // position se sama neaktualizuje — dokud se nešťouchne do signálu,
    // vazby drží poslední přečtenou hodnotu.
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
        color: Qt.rgba(Qt.color(Colors.surfaceContainerHigh).r,
                       Qt.color(Colors.surfaceContainerHigh).g,
                       Qt.color(Colors.surfaceContainerHigh).b, 0.95)
        border.color: Qt.rgba(Qt.color(Colors.outlineVariant).r,
                              Qt.color(Colors.outlineVariant).g,
                              Qt.color(Colors.outlineVariant).b, 0.6)
        border.width: 1
        clip: true

        // Album art banner
        Rectangle {
            id: artBanner
            visible: root.hasArt
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: visible ? 120 : 0
            color: Colors.surfaceContainer

            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
            }

            // Přes světlou náhledovku by byl bílý nadpis nečitelný, proto
            // přechod sahá výš a uprostřed už pořádně kryje.
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 96
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop {
                        position: 0.45
                        color: Qt.rgba(Qt.color(Colors.surfaceContainer).r,
                                       Qt.color(Colors.surfaceContainer).g,
                                       Qt.color(Colors.surfaceContainer).b, 0.75)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(Qt.color(Colors.surfaceContainer).r,
                                       Qt.color(Colors.surfaceContainer).g,
                                       Qt.color(Colors.surfaceContainer).b, 0.98)
                    }
                }
            }

            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.bottomMargin: 10
                spacing: 1

                Text {
                    width: parent.width
                    text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown") : ""
                    font.pixelSize: 14; font.weight: Font.DemiBold
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.onSurface; elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.activePlayer
                        ? (root.activePlayer.trackArtist || root.activePlayer.identity || "") : ""
                    font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                    color: Colors.onSurfaceVariant; elide: Text.ElideRight
                }
            }
        }

        // Controls + progress
        Column {
            anchors {
                left: parent.left; right: parent.right
                top: artBanner.bottom
                leftMargin: 14; rightMargin: 14; topMargin: 10
            }
            spacing: 8

            // Track info (no art)
            Column {
                visible: !root.hasArt
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown") : ""
                    font.pixelSize: 14; font.weight: Font.Medium
                    font.family: "JetBrainsMono Nerd Font"
                    color: Colors.onSurface; elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.activePlayer
                        ? (root.activePlayer.trackArtist || root.activePlayer.identity || "") : ""
                    font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                    color: Colors.onSurfaceVariant; elide: Text.ElideRight
                }
            }

            // Progress bar + seek
            Column {
                width: parent.width
                spacing: 4

                Rectangle {
                    id: progressBar
                    width: parent.width; height: 4; radius: 2
                    opacity: root.hasLength ? 1.0 : 0.45
                    color: Qt.rgba(Qt.color(Colors.outlineVariant).r,
                                   Qt.color(Colors.outlineVariant).g,
                                   Qt.color(Colors.outlineVariant).b, 0.5)

                    Rectangle {
                        width: parent.width * root.trackProgress
                        height: parent.height; radius: 2
                        color: Colors.primary
                        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
                    }

                    // Kliknutím se přeskakuje, ale jen když to přehrávač umí
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

                Row {
                    width: parent.width

                    Text {
                        id: posLbl
                        text: root.fmtTime(root.trackPos)
                        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                        color: Qt.rgba(Qt.color(Colors.onSurface).r,
                                       Qt.color(Colors.onSurface).g,
                                       Qt.color(Colors.onSurface).b, 0.55)
                    }
                    Item {
                        width: parent.width - posLbl.implicitWidth - durLbl.implicitWidth
                        height: 1
                    }
                    Text {
                        id: durLbl
                        text: root.hasLength ? root.fmtTime(root.effectiveLen) : "live"
                        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                        color: Qt.rgba(Qt.color(Colors.onSurface).r,
                                       Qt.color(Colors.onSurface).g,
                                       Qt.color(Colors.onSurface).b, 0.35)
                    }
                }
            }

            // Controls — zašedlé, když je přehrávač neumí
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                CtrlBtn {
                    icon: "\uf048"
                    enabled: !!root.activePlayer && root.activePlayer.canGoPrevious
                    onClicked: root.activePlayer.previous()
                }
                CtrlBtn {
                    icon: root.playing ? "\uf04c" : "\uf04b"
                    size: 36
                    enabled: !!root.activePlayer && root.activePlayer.canTogglePlaying
                    onClicked: root.activePlayer.togglePlaying()
                }
                CtrlBtn {
                    icon: "\uf051"
                    enabled: !!root.activePlayer && root.activePlayer.canGoNext
                    onClicked: root.activePlayer.next()
                }
            }
        }
    }

    component CtrlBtn: Rectangle {
        id: btn
        property string icon: ""
        property int size: 30
        property bool enabled: true
        signal clicked()

        width: size; height: size; radius: 8
        opacity: enabled ? 1.0 : 0.4
        color: (ma.containsMouse && enabled)
            ? Qt.rgba(Qt.color(Colors.primary).r, Qt.color(Colors.primary).g, Qt.color(Colors.primary).b, 0.15)
            : Qt.rgba(Qt.color(Colors.surfaceContainerHighest).r,
                      Qt.color(Colors.surfaceContainerHighest).g,
                      Qt.color(Colors.surfaceContainerHighest).b, 0.70)
        border.color: Qt.rgba(Qt.color(Colors.outlineVariant).r,
                              Qt.color(Colors.outlineVariant).g,
                              Qt.color(Colors.outlineVariant).b, 0.4)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.pixelSize: 15
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.onSurface
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
