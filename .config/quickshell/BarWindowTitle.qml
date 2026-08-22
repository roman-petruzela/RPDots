import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: lbl.visible ? Math.min(lbl.implicitWidth + 8, 280) : 0
    implicitHeight: parent ? parent.height : 40

    // Fed externally by Bar.qml
    property string title: ""

    Text {
        id: lbl
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        width: Math.min(implicitWidth, 272)
        text: root.title
        font.pixelSize: 12
        font.family: "JetBrainsMono Nerd Font"
        color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.55)
        elide: Text.ElideRight
        visible: root.title !== ""
    }
}
