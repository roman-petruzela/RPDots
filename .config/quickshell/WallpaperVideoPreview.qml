import QtQuick
import QtMultimedia

// Živý náhled video tapety ve vybrané kartě pickeru. Samostatný soubor
// načítaný přes Loader: kdyby QtMultimedia chyběla, selže jen tahle karta,
// ne celý WallpaperPicker.
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
        // Náhled pod tím zůstává vidět, dokud nedorazí první snímek
        opacity: position > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }
}
