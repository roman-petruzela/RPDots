import QtQuick
import QtMultimedia

Item {
    id: root

    property string path: ""

    Video {
        id: player
        anchors.fill: parent
        source: root.path !== "" ? "file://" + root.path : ""
        muted: true
        loops: MediaPlayer.Infinite
        autoPlay: true
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: position > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }
}
