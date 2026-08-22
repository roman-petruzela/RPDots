import Quickshell.Io
import QtQuick
import "Colors.js" as Colors

Item {
    id: root
    implicitWidth: row.implicitWidth + 8
    implicitHeight: parent ? parent.height : 40

    // Fed externally by Bar.qml from event-stream / poll
    property var  workspaces: []
    property string screenOutput: ""

    // Use ListModel so Repeater reliably detects changes
    ListModel { id: wsModel }

    // Rebuild ListModel whenever input changes
    function rebuild() {
        wsModel.clear()
        var src = workspaces.slice()
        if (screenOutput) src = src.filter(w => w.output === screenOutput)
        src.sort((a, b) => (a.idx || 0) - (b.idx || 0))
        for (var i = 0; i < src.length; i++) {
            var w = src[i]
            wsModel.append({
                ws_id:      w.id         || 0,
                ws_idx:     w.idx        || 0,
                ws_active:  w.is_active  || false,
                ws_focused: w.is_focused || false,
                ws_occupied: (w.active_window_id != null)
            })
        }
    }

    onWorkspacesChanged: rebuild()
    onScreenOutputChanged: rebuild()
    Component.onCompleted: rebuild()

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 3

        Repeater {
            model: wsModel
            delegate: Rectangle {
                required property int    index
                required property int    ws_idx
                required property bool   ws_active
                required property bool   ws_focused
                required property bool   ws_occupied

                property bool active:   ws_active
                property bool focused:  ws_focused
                property bool occupied: ws_occupied

                width:  active ? 26 : (occupied ? 13 : 9)
                height: active ? 22 : (occupied ?  8 : 6)
                radius: height / 2
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                color: focused
                    ? Colors.primary
                    : active
                        ? Qt.rgba(Qt.color(Colors.primary).r, Qt.color(Colors.primary).g, Qt.color(Colors.primary).b, 0.65)
                        : occupied
                            ? Qt.rgba(Qt.color(Colors.primary).r, Qt.color(Colors.primary).g, Qt.color(Colors.primary).b, 0.28)
                            : Qt.rgba(Qt.color(Colors.onSurface).r, Qt.color(Colors.onSurface).g, Qt.color(Colors.onSurface).b, 0.15)

                Behavior on width  { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color  { ColorAnimation  { duration: 150 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
                        p.command = ["niri", "msg", "action", "focus-workspace", String(ws_idx)]
                        p.running = true
                    }
                }
            }
        }
    }
}
