import Quickshell.Services.UPower
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: row.implicitWidth + 8
    implicitHeight: parent ? parent.height : 40
    visible: UPower.onBattery || (UPower.displayDevice && UPower.displayDevice.percentage < 1.0)

    property var bat: UPower.displayDevice
    // percentage is 0.0–1.0 in QS UPower binding
    property int pct: bat ? Math.round(bat.percentage * 100) : 0
    property string state: bat ? bat.state : "Unknown"
    property bool charging: state === "Charging" || state === "FullyCharged" || state === "PendingCharge"

    function batIcon() {
        if (charging) return pct >= 90 ? "󰂅" : pct >= 60 ? "󰂈" : pct >= 30 ? "󰂆" : "󰢜"
        if (pct >= 90) return "󰁹"
        if (pct >= 70) return "󰂀"
        if (pct >= 50) return "󰁾"
        if (pct >= 30) return "󰁼"
        if (pct >= 20) return "󰁻"
        if (pct >= 10) return "󰁺"
        return "󰂎"
    }

    function batColor() {
        if (charging) return Colors.tertiary
        if (pct <= 10) return Colors.errorColor
        if (pct <= 25) return Colors.tertiary
        return Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.7)
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 3

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.batIcon()
            font.pixelSize: 14
            font.family: "JetBrainsMono Nerd Font"
            color: root.batColor()
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pct + "%"
            font.pixelSize: 12
            font.family: "JetBrainsMono Nerd Font"
            color: root.batColor()
        }
    }
}
