import QtQuick
import "Colors.js" as Colors

Item {
    implicitWidth: 340
    implicitHeight: headerRow.height + 10 + dayNamesRow.height + 6 + calGrid.height

    property int viewYear:  (new Date()).getFullYear()
    property int viewMonth: (new Date()).getMonth()
    readonly property var today: new Date()

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]

    ListModel { id: calModel }

    function build() {
        calModel.clear()
        var first = new Date(viewYear, viewMonth, 1).getDay()
        first = first === 0 ? 7 : first          // Mon=1 … Sun=7
        var dim  = new Date(viewYear, viewMonth + 1, 0).getDate()
        var prev = new Date(viewYear, viewMonth, 0).getDate()

        for (var i = first - 1; i > 0; i--)
            calModel.append({ d: prev - i + 1, cur: false, now: false })

        var ty = today.getFullYear(), tm = today.getMonth(), td = today.getDate()
        for (var day = 1; day <= dim; day++)
            calModel.append({ d: day, cur: true, now: (viewYear===ty && viewMonth===tm && day===td) })

        var rem = 42 - calModel.count
        for (var n = 1; n <= rem; n++)
            calModel.append({ d: n, cur: false, now: false })
    }

    function prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear-- }
        else viewMonth--
        build()
    }

    function nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear++ }
        else viewMonth++
        build()
    }

    Component.onCompleted: build()

    // Header
    Item {
        id: headerRow
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: monthNames[viewMonth] + " " + viewYear
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Colors.onSurface
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Rectangle {
                width: 24; height: 24; radius: 6
                color: prevHover.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 15; color: Colors.onSurfaceVariant }
                MouseArea { id: prevHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: prevMonth() }
            }
            Rectangle {
                width: 24; height: 24; radius: 6
                color: nextHover.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 15; color: Colors.onSurfaceVariant }
                MouseArea { id: nextHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nextMonth() }
            }
        }
    }

    // Day name headers
    Row {
        id: dayNamesRow
        anchors.top: headerRow.bottom
        anchors.topMargin: 10
        width: parent.width

        Repeater {
            model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
            Text {
                width: parent.width / 7
                text: modelData
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Colors.outline
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Day grid
    Grid {
        id: calGrid
        anchors.top: dayNamesRow.bottom
        anchors.topMargin: 6
        width: parent.width
        columns: 7

        Repeater {
            model: calModel
            Item {
                width: calGrid.width / 7
                height: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 26; height: 26
                    radius: 13
                    color: model.now ? Colors.primary : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: model.d
                    font.pixelSize: 12
                    font.weight: model.now ? Font.Medium : Font.Normal
                    color: model.now  ? Colors.onPrimary
                         : model.cur ? Colors.onSurface
                         : Colors.outline
                }
            }
        }
    }
}
