import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: col.implicitWidth + 16
    implicitHeight: parent ? parent.height : 40

    property string timeStr: "00:00"
    property string dateStr: "Mon 01"

    Timer {
        interval: 10000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            var h = now.getHours()
            var m = now.getMinutes()
            root.timeStr = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
            var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
            var d = now.getDate()
            root.dateStr = days[now.getDay()] + " " + (d < 10 ? "0" : "") + d + " " + months[now.getMonth()]
        }
    }

    Column {
        id: col
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: -2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeStr
            font.pixelSize: 14
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
            color: Colors.primary
            font.letterSpacing: 1
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateStr
            font.pixelSize: 10
            font.family: "JetBrainsMono Nerd Font"
            color: Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.55)
        }
    }
}
