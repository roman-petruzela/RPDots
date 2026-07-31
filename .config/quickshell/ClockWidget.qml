import Quickshell
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: 108

    SystemClock { id: clock; precision: SystemClock.Seconds }

    property string timeStr: Qt.formatTime(new Date(), "HH:mm")
    property string secsStr: Qt.formatTime(new Date(), "ss")
    property string dayStr:  Qt.formatDate(new Date(), "dddd")
    property string dateStr: Qt.formatDate(new Date(), "d MMMM yyyy")

    Connections {
        target: clock
        function onSecondsChanged() {
            var d = new Date()
            timeStr = Qt.formatTime(d, "HH:mm")
            secsStr = Qt.formatTime(d, "ss")
            dayStr  = Qt.formatDate(d, "dddd")
            dateStr = Qt.formatDate(d, "d MMMM yyyy")
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // HH:mm + :ss on one baseline
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: timeLabel.implicitWidth + secLabel.implicitWidth + 4
            implicitHeight: timeLabel.implicitHeight

            Text {
                id: timeLabel
                text: timeStr
                font.pixelSize: 72
                font.weight: Font.Thin
                color: Colors.primary
                anchors.left: parent.left
                anchors.bottom: parent.bottom
            }

            Text {
                id: secLabel
                text: secsStr
                font.pixelSize: 26
                font.weight: Font.Light
                color: Colors.outline
                anchors.left: timeLabel.right
                anchors.leftMargin: 3
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Text {
                text: dayStr
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Colors.onSurfaceVariant
            }
            Text {
                text: "·"
                font.pixelSize: 13
                color: Colors.outline
            }
            Text {
                text: dateStr
                font.pixelSize: 13
                color: Colors.onSurfaceVariant
            }
        }
    }
}
