import QtQuick
import "Colors.js" as Colors

Text {
    property string title: ""
    text: title.toUpperCase()
    font.pixelSize: 10
    font.weight: Font.Medium
    font.letterSpacing: 1.5
    color: Colors.outline
}
