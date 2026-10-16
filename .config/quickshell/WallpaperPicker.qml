import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "Colors.js" as Colors

PanelWindow {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    property var entries: []
    property string filter: ""
    property bool applying: false
    property bool videoAllowed: true
    property int settledIndex: -1
    property bool instantMove: false
    property int thumbEpoch: 0
    property string listSig: ""
    property string currentPath: ""
    property bool zoomDone: false
    property bool wallpaperShown: false
    property bool previewActive: false
    property url previewSource: ""
    property url previewThumb: ""
    property real fade: 0

    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rp-wallpaper-picker"
    WlrLayershell.keyboardFocus: root.visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    FocusedOutput { id: opener; window: root }

    function open() {
        applying = false
        filter = ""
        zoomAnim.stop()
        closeAnim.stop()
        stage.opacity = 1
        launch.visible = false
        launch.opacity = 1
        focusPath(currentPath)
        previewActive = true
        previewTimer.restart()
        lister.running = false
        lister.running = true
        inhibitCheck.running = false
        inhibitCheck.running = true
        if (visible) openAnim.restart()
        else fade = 0
        opener.show()
    }

    function close() {
        if (!visible || applying || closeAnim.running) return
        openAnim.stop()
        closeAnim.start()
    }

    function toggle() {
        if (root.visible) root.close()
        else root.open()
    }

    onVisibleChanged: {
        if (visible) {
            if (!applying) openAnim.restart()
            return
        }
        openAnim.stop()
        closeAnim.stop()
        settledIndex = -1
        if (!applying) previewActive = false
    }

    NumberAnimation {
        id: openAnim
        target: root; property: "fade"; from: 0; to: 1
        duration: 200; easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: root; property: "fade"; to: 0
        duration: 140; easing.type: Easing.InQuad
        onFinished: root.visible = false
    }

    Process {
        id: lister
        command: [root.home + "/.local/bin/pick-wallpaper.sh", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const f = line.split("\t")
                    if (f.length < 4) continue
                    const name = root.prettyName(f[0])
                    list.push({
                        path: f[0],
                        thumb: f[1],
                        video: f[2] === "video",
                        current: f[3] === "1",
                        name: name,
                        search: (name + " " + f[0].split("/").pop()).toLowerCase()
                    })
                }
                const cur = list.find(e => e.current)
                const curPath = cur ? cur.path : ""
                const sig = list.map(e => e.path + "\t" + e.thumb).join("\n")
                root.entries = list
                if (sig !== root.listSig) {
                    root.listSig = sig
                    root.currentPath = curPath
                    root.rebuild(curPath)
                } else if (curPath !== root.currentPath) {
                    root.markCurrent(curPath)
                    root.focusPath(curPath)
                }
                shownSignal.path = ""
                shownSignal.path = root.shownFile
            }
        }
    }

    Process {
        id: inhibitCheck
        command: ["test", "-e", root.home + "/.cache/niri-rice/video-inhibit"]
        onExited: code => root.videoAllowed = code !== 0
    }

    ListModel { id: shown }

    function focusPath(path) {
        for (let i = 0; i < shown.count; i++) {
            if (shown.get(i).path !== path) continue
            view.jump(i)
            return
        }
    }

    function markCurrent(path) {
        currentPath = path
        for (const e of entries) e.current = e.path === path
        for (let i = 0; i < shown.count; i++)
            shown.setProperty(i, "current", shown.get(i).path === path)
    }

    function rebuild(focusPath) {
        const q = filter.trim().toLowerCase()
        shown.clear()
        let focus = 0
        for (const e of entries) {
            if (q !== "" && !e.search.includes(q)) continue
            if (e.path === focusPath) focus = shown.count
            shown.append(e)
        }
        view.jump(Math.min(focus, Math.max(shown.count - 1, 0)))
        settleTimer.restart()
    }

    onFilterChanged: {
        const cur = currentEntry()
        rebuild(cur ? cur.path : "")
    }

    function currentEntry() {
        return shown.count > 0 && view.currentIndex >= 0 ? shown.get(view.currentIndex) : null
    }

    function prettyName(path) {
        const file = path.split("/").pop()
        let n = file.replace(/\.[^.]+$/, "")
            .replace(/[-_.]?moewalls[-_.]com$/i, "")
            .replace(/[-_.]\d{3,5}x\d{3,5}([-_.]\d+)?$/i, "")
            .replace(/[-_]\d{6,}$/, "")
            .replace(/[-_.]+/g, " ")
            .trim()
        return n ? n.charAt(0).toUpperCase() + n.slice(1) : file
    }

    function step(delta) {
        if (shown.count === 0) return
        if (view.wraps) view.moveTo(view.target + delta)
        else view.moveTo(view.wrapIndex(view.target + delta))
    }

    readonly property string shownFile: home + "/.cache/niri-rice/wallpaper-shown"

    function apply() {
        const e = currentEntry()
        if (!e || applying) return
        applying = true
        zoomDone = false
        wallpaperShown = false
        markCurrent(e.path)
        Quickshell.execDetached(["env", "AWWW_TRANSITION_TYPE=none", "WALL_TRANSITION_TYPE=none",
                                 root.home + "/.local/bin/apply-wallpaper-theme.sh", e.path])
        launchImage.source = "file://" + e.thumb
        launch.visible = true
        zoomAnim.start()
        revealTimeout.restart()
    }

    function maybeReveal() {
        if (!applying || !zoomDone || !wallpaperShown) return
        revealTimeout.stop()
        previewActive = false
        applying = false
    }

    FileView {
        id: shownSignal
        watchChanges: true
        onFileChanged: {
            if (!root.applying) return
            root.wallpaperShown = true
            root.maybeReveal()
        }
    }

    Timer {
        id: revealTimeout
        interval: 2500
        onTriggered: {
            root.wallpaperShown = true
            root.maybeReveal()
        }
    }

    Timer {
        id: settleTimer
        interval: 450
        onTriggered: root.settledIndex = view.currentIndex
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.visible
        onTriggered: root.thumbEpoch++
    }

    Timer {
        id: previewTimer
        interval: 110
        onTriggered: {
            const e = root.currentEntry()
            if (e) root.previewSource = "file://" + (e.video ? e.thumb : e.path)
        }
    }

    function updatePreviewThumb() {
        const e = currentEntry()
        if (e) previewThumb = "file://" + e.thumb
    }

    Rectangle {
        anchors.fill: parent
        opacity: root.fade
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Colors.background, 0.15) }
            GradientStop { position: 0.6; color: Qt.alpha(Colors.background, 0.3) }
            GradientStop { position: 1.0; color: Qt.alpha(Colors.background, 0.75) }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
        onWheel: wheel => {
            wheelAccum += wheel.angleDelta.y + wheel.angleDelta.x
            while (Math.abs(wheelAccum) >= 120) {
                root.step(wheelAccum > 0 ? -1 : 1)
                wheelAccum -= wheelAccum > 0 ? 120 : -120
            }
        }
        property real wheelAccum: 0
    }

    Item {
        id: stage
        anchors.fill: parent
        focus: root.visible
        opacity: 0
        scale: 0.97 + 0.03 * root.fade

        readonly property real cardW: Math.min(width * 0.44, 900)
        readonly property real cardH: cardW * 9 / 16
        readonly property real cx: width / 2
        readonly property real cy: height * 0.45

        Keys.onPressed: event => {
            if (root.applying) { event.accepted = true; return }
            const ctrl = event.modifiers & Qt.ControlModifier
            switch (event.key) {
            case Qt.Key_Left:     root.step(-1); break
            case Qt.Key_Right:    root.step(1); break
            case Qt.Key_Up:       root.step(10); break
            case Qt.Key_Down:     root.step(-10); break
            case Qt.Key_PageUp:   root.step(-5); break
            case Qt.Key_PageDown: root.step(5); break
            case Qt.Key_Home:     view.goTo(0); break
            case Qt.Key_End:      view.goTo(Math.max(shown.count - 1, 0)); break
            case Qt.Key_Return:
            case Qt.Key_Enter:    root.apply(); break
            case Qt.Key_Escape:
                if (root.filter !== "") root.filter = ""
                else root.close()
                break
            case Qt.Key_Backspace:
                root.filter = ctrl ? "" : root.filter.slice(0, -1)
                break
            default:
                if (ctrl && event.key === Qt.Key_R) {
                    if (shown.count > 1)
                        root.step(1 + Math.floor(Math.random() * (shown.count - 1)))
                } else if (!ctrl && event.text.length === 1 && event.text >= " ") {
                    root.filter += event.text
                } else {
                    return
                }
            }
            event.accepted = true
        }

        Item {
            id: view

            x: 0
            width: parent.width
            y: stage.cy - height / 2
            height: stage.cardH * 1.25
            opacity: root.fade

            property int currentIndex: 0
            property real target: 0
            property real pos: 0
            property bool dragging: false
            readonly property int count: shown.count
            readonly property bool wraps: count > 7
            readonly property real mid: height / 2
            readonly property real knee: stage.cardW * 0.62
            readonly property real side: stage.cardW * 0.21

            Behavior on pos {
                enabled: !root.instantMove && !view.dragging
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            onCurrentIndexChanged: {
                settleTimer.restart()
                previewTimer.restart()
                root.updatePreviewThumb()
            }

            function wrapIndex(i) {
                return count > 0 ? ((Math.round(i) % count) + count) % count : 0
            }

            function moveTo(t) {
                target = t
                pos = t
                currentIndex = wrapIndex(t)
            }

            function jump(i) {
                root.instantMove = true
                moveTo(i)
                root.instantMove = false
            }

            function goTo(i) {
                if (!wraps) { moveTo(i); return }
                let d = ((i - currentIndex) % count + count) % count
                if (d > count / 2) d -= count
                moveTo(target + d)
            }

            DragHandler {
                target: null
                yAxis.enabled: false
                property real startPos: 0
                onActiveChanged: {
                    if (active) {
                        startPos = view.pos
                        view.dragging = true
                        return
                    }
                    view.dragging = false
                    const p = Math.round(view.pos)
                    view.moveTo(view.wraps ? p : Math.max(0, Math.min(view.count - 1, p)))
                }
                onActiveTranslationChanged: {
                    if (!active || root.applying) return
                    let p = startPos - activeTranslation.x / view.knee
                    if (!view.wraps) p = Math.max(-0.35, Math.min(view.count - 0.65, p))
                    view.pos = p
                    view.currentIndex = view.wrapIndex(p)
                }
            }

            Repeater {
                model: shown

                delegate: Item {
                    id: card

                    required property int index
                    required property string path
                    required property string thumb
                    required property string name
                    required property bool video

                    readonly property real off: {
                        let o = index - view.pos
                        if (view.wraps) {
                            const n = view.count
                            o = ((o % n) + n) % n
                            if (o > n / 2) o -= n
                        }
                        return o
                    }
                    readonly property real a: Math.abs(off)
                    readonly property real sgn: off < 0 ? -1 : 1
                    readonly property real inner: Math.min(a, 1)
                    readonly property real outer: Math.min(Math.max(a - 1, 0), 1)
                    readonly property bool focused: index === view.currentIndex
                    readonly property bool near: a < 5.5
                    readonly property url thumbUrl: "file://" + thumb

                    visible: a < 4.5
                    width: stage.cardW
                    height: stage.cardH
                    x: stage.cx - width / 2 + sgn * (inner * view.knee + Math.max(a - 1, 0) * view.side)
                    y: view.mid - height / 2
                    z: 100 - a * 10
                    scale: 1 - 0.28 * inner - 0.12 * outer
                    opacity: Math.min(1, 4.5 - a)

                    transform: Rotation {
                        origin.x: card.width / 2
                        origin.y: card.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: -card.sgn * (56 * card.inner + 8 * card.outer)
                    }

                    ClippingRectangle {
                        id: face
                        anchors.fill: parent
                        radius: 14
                        color: Colors.surfaceContainer

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 48
                            visible: img.status !== Image.Ready
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: card.name + "\n\nPreparing preview"
                            font.family: root.fontFamily
                            font.pixelSize: 15
                            color: Colors.onSurfaceVariant
                        }

                        Image {
                            id: img
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(960, 540)
                            source: card.near ? card.thumbUrl : ""

                            Connections {
                                target: root
                                function onThumbEpochChanged() {
                                    if (img.status === Image.Error) {
                                        img.source = ""
                                        img.source = card.thumbUrl
                                    }
                                }
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: card.video && card.focused && card.a < 0.01 && root.visible
                                && root.videoAllowed && !root.applying
                                && root.settledIndex === card.index
                            source: "WallpaperVideoPreview.qml"
                            onLoaded: item.path = card.path
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: 0.45 * card.inner + 0.3 * card.outer
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: face.radius
                        color: "transparent"
                        border.width: card.focused ? 2 : 1
                        border.color: card.focused ? Colors.primary : Qt.alpha(Colors.onSurface, 0.14)
                    }

                    Rectangle {
                        visible: card.video
                        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                        width: 30; height: 30; radius: 15
                        color: Qt.alpha(Colors.background, 0.7)
                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 1
                            text: "▶"
                            font.pixelSize: 12
                            color: Colors.onSurface
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.focused && card.a < 0.5) root.apply()
                            else view.moveTo(Math.round(view.pos + card.off))
                        }
                    }
                }
            }
        }

        Column {
            id: caption
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.cy + stage.cardH / 2 + 34
            width: stage.cardW
            spacing: 10
            visible: shown.count > 0
            opacity: root.fade

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.currentEntry()?.name ?? ""
                font.family: root.fontFamily
                font.pixelSize: 22
                font.weight: Font.Medium
                color: Colors.onSurface
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                Rectangle {
                    visible: root.currentEntry()?.current ?? false
                    anchors.verticalCenter: parent.verticalCenter
                    width: currentLabel.implicitWidth + 16
                    height: currentLabel.implicitHeight + 6
                    radius: height / 2
                    color: Colors.primaryContainer
                    Text {
                        id: currentLabel
                        anchors.centerIn: parent
                        text: "Current"
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        color: Colors.onPrimaryContainer
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.currentEntry()?.video ?? false) ? "Video" : "Image"
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    color: Colors.onSurfaceVariant
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (view.currentIndex + 1) + " / " + shown.count
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    color: Colors.onSurfaceVariant
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: shown.count === 0 && !lister.running
            horizontalAlignment: Text.AlignHCenter
            text: root.filter !== ""
                ? "No wallpaper matches “" + root.filter + "”.\nBackspace edits the filter, Esc clears it."
                : "No wallpapers found.\nAdd images or videos to ~/Pictures/Wallpapers."
            font.family: root.fontFamily
            font.pixelSize: 16
            lineHeight: 1.3
            color: Colors.onSurface
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            opacity: root.fade
            spacing: 28

            Text {
                visible: root.filter !== ""
                text: "Filter  " + root.filter + "▏"
                font.family: root.fontFamily
                font.pixelSize: 14
                color: Colors.primary
            }

            Repeater {
                model: root.filter !== ""
                    ? [["Esc", "clear filter"]]
                    : [["← →", "browse"], ["↑ ↓", "jump 10"], ["Enter", "apply"], ["Ctrl R", "surprise me"],
                       ["Type", "to filter"], ["Esc", "close"]]

                Row {
                    required property var modelData
                    spacing: 7
                    Text {
                        text: modelData[0]
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Colors.onSurface
                    }
                    Text {
                        text: modelData[1]
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        color: Colors.onSurfaceVariant
                    }
                }
            }
        }
    }

    ClippingRectangle {
        id: launch
        visible: false
        radius: 14
        color: "transparent"
        x: stage.cx - stage.cardW / 2
        y: stage.cy - stage.cardH / 2
        width: stage.cardW
        height: stage.cardH

        Image {
            id: launchImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: false
        }
    }

    SequentialAnimation {
        id: zoomAnim
        ParallelAnimation {
            NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 140 }
            NumberAnimation { target: launch; property: "x"; from: stage.cx - stage.cardW / 2; to: 0; duration: 260; easing.type: Easing.OutQuart }
            NumberAnimation { target: launch; property: "y"; from: stage.cy - stage.cardH / 2; to: 0; duration: 260; easing.type: Easing.OutQuart }
            NumberAnimation { target: launch; property: "width"; from: stage.cardW; to: root.width; duration: 260; easing.type: Easing.OutQuart }
            NumberAnimation { target: launch; property: "height"; from: stage.cardH; to: root.height; duration: 260; easing.type: Easing.OutQuart }
            NumberAnimation { target: launch; property: "radius"; from: 14; to: 0; duration: 260 }
        }
        ParallelAnimation {
            NumberAnimation { target: launch; property: "opacity"; from: 1; to: 0; duration: 180; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "fade"; to: 0; duration: 180; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                root.visible = false
                launch.visible = false
                launch.opacity = 1
                root.zoomDone = true
                root.maybeReveal()
            }
        }
    }
}
