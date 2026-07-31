import Quickshell
import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: 140

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 64
            font.weight: Font.Light
            color: Colors.primary

            Connections {
                target: clock
                function onSecondsChanged() {
                    timeText.text = Qt.formatTime(new Date(), "HH:mm")
                    dateText.text = Qt.formatDate(new Date(), "dddd, d. MMMM yyyy")
                }
            }

            Component.onCompleted: {
                text = Qt.formatTime(new Date(), "HH:mm")
            }
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 13
            color: Colors.onSurfaceVariant

            Component.onCompleted: {
                text = Qt.formatDate(new Date(), "dddd, d. MMMM yyyy")
            }
        }
    }
}
