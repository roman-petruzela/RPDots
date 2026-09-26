import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Rozbalovací seznam pro enumy s víc volbami (nebo dlouhými popisky)
ComboBox {
    id: dd
    property var options: []
    property var labels: []
    property string current
    signal picked(string value)

    width: 240
    height: 32
    model: options.map((o, i) => labels[i] ?? o)
    currentIndex: options.indexOf(current)
    onActivated: i => dd.picked(options[i])
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 12

    background: Rectangle {
        radius: 10
        color: dd.hovered ? Qt.alpha(Colors.onSurface, 0.08) : Colors.surfaceContainerHighest
        border.width: 1
        border.color: dd.popup.visible ? Colors.primary : Colors.outlineVariant
    }
    contentItem: Text {
        leftPadding: 12
        rightPadding: 30
        text: dd.displayText
        font: dd.font
        color: Colors.onSurface
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: dd.width - width - 12
        anchors.verticalCenter: parent.verticalCenter
        text: dd.popup.visible ? "󰅃" : "󰅀"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: Colors.onSurfaceVariant
    }
    delegate: ItemDelegate {
        id: ddItem
        required property var modelData
        required property int index
        width: dd.width - 12
        height: 30
        highlighted: dd.highlightedIndex === index
        contentItem: Text {
            text: ddItem.modelData
            font: dd.font
            color: ddItem.index === dd.currentIndex ? Colors.primary : Colors.onSurface
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 8
            color: ddItem.highlighted ? Qt.alpha(Colors.primary, 0.18) : "transparent"
        }
    }
    popup: Popup {
        y: dd.height + 4
        width: dd.width
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 320)
        padding: 6
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: dd.popup.visible ? dd.delegateModel : null
            currentIndex: dd.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle {
            radius: 12
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Colors.outlineVariant
        }
    }
}
