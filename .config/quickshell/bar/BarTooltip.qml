import QtQuick
import "../Colors.js" as Colors

BarPopup {
    id: tip
    property string text: ""
    property bool wanted: false
    padding: 10

    Timer {
        id: delay
        interval: 450
        onTriggered: if (tip.wanted && tip.text !== "") tip.show()
    }
    onWantedChanged: {
        if (wanted) delay.restart()
        else { delay.stop(); dismiss() }
    }

    Text {
        text: tip.text
        font.family: "JetBrainsMono Nerd Font Mono"
        font.pixelSize: 12
        color: Colors.onSurface
        lineHeight: 1.1
    }
}
