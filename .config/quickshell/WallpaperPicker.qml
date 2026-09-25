import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "Colors.js" as Colors

// Výběr tapety (Mod+Shift+W) jako 3D coverflow přes celou obrazovku.
// Pozadí je rozmazaná právě vybraná tapeta, takže ještě před potvrzením je
// vidět, jak bude plocha zhruba vypadat.
//
// Seznam i náhledy dodává `pick-wallpaper.sh --list` (stejná cache jako rofi
// fallback). Chybějící náhledy se generují na pozadí; karty je zkoušejí
// načíst znovu, dokud se neobjeví. Po výběru se spouští
// apply-wallpaper-theme.sh — nikdy ne matugen přímo (viz README).
PanelWindow {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    property var entries: []
    property string filter: ""
    property bool applying: false
    property bool videoAllowed: true
    // Index, na kterém se listování zastavilo — až na něm se rozehraje video.
    property int settledIndex: -1
    // Při otevření se má skočit rovnou na aktuální tapetu, ne k ní dojet.
    property bool instantMove: false
    property int thumbEpoch: 0
    // Cesty+náhledy posledního výpisu. Když se nezmění, model se nepřestavuje —
    // karty i načtené náhledy přežijí zavření a picker se otevře hned hotový.
    property string listSig: ""
    property string currentPath: ""
    // Sekvence po výběru: zoom doběhl / tapeta je opravdu na ploše
    property bool zoomDone: false
    property bool wallpaperShown: false

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

    // Otevírá se bez animace — picker má reagovat stejně rychle jako fuzzel.
    function open() {
        applying = false
        filter = ""
        stage.opacity = 1
        backdrop.opacity = 1
        launch.visible = false
        focusPath(currentPath)
        lister.running = false
        lister.running = true
        inhibitCheck.running = false
        inhibitCheck.running = true
        opener.show()
    }

    function toggle() {
        if (root.visible) root.visible = false
        else root.open()
    }

    onVisibleChanged: if (!visible) settledIndex = -1

    // ---------------------------------------------------------------- data

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
                    // Tapetu mezitím změnilo něco jiného než picker
                    root.markCurrent(curPath)
                    root.focusPath(curPath)
                }
                // --list soubor se signálem založil; znovu nastavená cesta
                // zajistí, že ho FileView opravdu sleduje.
                shownSignal.path = ""
                shownSignal.path = root.shownFile
            }
        }
    }

    // rp-power (battery/gaming) potlačuje video tapety — pak nehraje ani náhled.
    Process {
        id: inhibitCheck
        command: ["test", "-e", root.home + "/.cache/niri-rice/video-inhibit"]
        onExited: code => root.videoAllowed = code !== 0
    }

    ListModel { id: shown }

    function focusPath(path) {
        for (let i = 0; i < shown.count; i++) {
            if (shown.get(i).path !== path) continue
            instantMove = true
            view.currentIndex = i
            instantMove = false
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
        instantMove = true
        view.currentIndex = Math.min(focus, Math.max(shown.count - 1, 0))
        instantMove = false
        settleTimer.restart()
    }

    onFilterChanged: {
        const cur = currentEntry()
        rebuild(cur ? cur.path : "")
    }

    function currentEntry() {
        return shown.count > 0 && view.currentIndex >= 0 ? shown.get(view.currentIndex) : null
    }

    // "lone-tree-crescent-moon-3840x2160-7701.jpg" → "Lone tree crescent moon"
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
        view.currentIndex = ((view.currentIndex + delta) % shown.count + shown.count) % shown.count
    }

    // Přechod dělá picker sám (zoom karty), awww proto dostane "none" a jen
    // tapetu okamžitě vymění. Náhled zůstane přes obrazovku, dokud
    // wallpaper-video-ctl.sh nezapíše wallpaper-shown (awww hotový, staré
    // video pryč) — teprve pak se rozpustí, takže přepnutí působí okamžitě.
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
        // U obrázku se na pozadí dotáhne plné rozlišení, ať rozmazaný 960px
        // náhled nevisí přes celou obrazovku. U videa awww ukazuje jiný snímek
        // než náhled, tam by to nepomohlo.
        launchFull.source = e.video ? "" : "file://" + e.path
        launch.visible = true
        zoomAnim.start()
        revealTimeout.restart()
    }

    function maybeReveal() {
        if (applying && zoomDone && wallpaperShown && !revealAnim.running) revealAnim.start()
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

    // Pojistka, kdyby signál nepřišel (např. chybí mpvpaper skript)
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

    // ------------------------------------------------------------ backdrop

    // Dvě vrstvy kvůli prolínání: nový náhled se načte do zadní, a až je
    // hotový, prohodí se. Rozmazává se v malém rozlišení — je to levnější
    // a 960px náhled by v plné velikosti stejně nebyl ostrý.
    property bool frontIsA: true

    Timer {
        id: backdropTimer
        interval: 90
        onTriggered: {
            const e = root.currentEntry()
            if (!e) return
            const src = "file://" + e.thumb
            const front = root.frontIsA ? backA : backB
            const back = root.frontIsA ? backB : backA
            if (front.source.toString() === src) return
            if (back.source.toString() === src && back.status === Image.Ready)
                root.frontIsA = !root.frontIsA
            else
                back.source = src
        }
    }

    Item {
        id: backdrop
        anchors.fill: parent
        layer.enabled: true
        layer.textureSize: Qt.size(width / 3, height / 3)
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.15
        }

        Rectangle { anchors.fill: parent; color: Colors.background }

        Image {
            id: backA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: root.frontIsA ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready && !root.frontIsA) root.frontIsA = true
        }

        Image {
            id: backB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: root.frontIsA ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready && root.frontIsA) root.frontIsA = false
        }
    }

    // Závoj: nahoře lehký, dole tmavší, aby byl popisek čitelný nad čímkoli.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Colors.background, 0.35) }
            GradientStop { position: 0.6; color: Qt.alpha(Colors.background, 0.45) }
            GradientStop { position: 1.0; color: Qt.alpha(Colors.background, 0.85) }
        }
    }

    // Kliknutí mimo karty zavírá
    MouseArea {
        anchors.fill: parent
        onClicked: if (!root.applying) root.visible = false
        onWheel: wheel => {
            wheelAccum += wheel.angleDelta.y + wheel.angleDelta.x
            while (Math.abs(wheelAccum) >= 120) {
                root.step(wheelAccum > 0 ? -1 : 1)
                wheelAccum -= wheelAccum > 0 ? 120 : -120
            }
        }
        property real wheelAccum: 0
    }

    // ------------------------------------------------------------ carousel

    Item {
        id: stage
        anchors.fill: parent
        focus: root.visible
        opacity: 0

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
            case Qt.Key_PageUp:   root.step(-5); break
            case Qt.Key_PageDown: root.step(5); break
            case Qt.Key_Home:     view.currentIndex = 0; break
            case Qt.Key_End:      view.currentIndex = Math.max(shown.count - 1, 0); break
            case Qt.Key_Return:
            case Qt.Key_Enter:    root.apply(); break
            case Qt.Key_Escape:
                if (root.filter !== "") root.filter = ""
                else root.visible = false
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

        PathView {
            id: view

            x: 0
            width: parent.width
            y: stage.cy - height / 2
            height: stage.cardH * 1.25

            model: shown
            pathItemCount: 7
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: root.instantMove ? 0 : 170
            snapMode: PathView.SnapOneItem
            flickDeceleration: 900
            cacheItemCount: 2

            onCurrentIndexChanged: {
                settleTimer.restart()
                backdropTimer.restart()
            }

            readonly property real mid: height / 2
            // Vzdálenost prvního bočního páru od středu. Pod prostřední kartu
            // zajíždí jen kousek — jako listy knihy, ne jako naskládané karty.
            readonly property real knee: stage.cardW * 0.62

            // Prostředek dráhy je roztažený (střed ↔ první soused), okraje
            // stlačené — boční karty se tak vrství, zatímco vybraná má kolem
            // sebe místo. Soused sedí přesně v „koleni“ (0.5 ± 1/7).
            path: Path {
                startX: -stage.cardW * 0.15; startY: view.mid
                PathAttribute { name: "angle"; value: 64 }
                PathAttribute { name: "cardScale"; value: 0.6 }
                PathAttribute { name: "depth"; value: 0 }
                PathAttribute { name: "dim"; value: 0.75 }

                PathLine { x: stage.cx - view.knee; y: view.mid }
                PathPercent { value: 0.5 - 1 / 7 }
                PathAttribute { name: "angle"; value: 56 }
                PathAttribute { name: "cardScale"; value: 0.72 }
                PathAttribute { name: "depth"; value: 50 }
                PathAttribute { name: "dim"; value: 0.45 }

                PathLine { x: stage.cx; y: view.mid }
                PathPercent { value: 0.5 }
                PathAttribute { name: "angle"; value: 0 }
                PathAttribute { name: "cardScale"; value: 1 }
                PathAttribute { name: "depth"; value: 100 }
                PathAttribute { name: "dim"; value: 0 }

                PathLine { x: stage.cx + view.knee; y: view.mid }
                PathPercent { value: 0.5 + 1 / 7 }
                PathAttribute { name: "angle"; value: -56 }
                PathAttribute { name: "cardScale"; value: 0.72 }
                PathAttribute { name: "depth"; value: 50 }
                PathAttribute { name: "dim"; value: 0.45 }

                PathLine { x: stage.width + stage.cardW * 0.15; y: view.mid }
                PathPercent { value: 1 }
                PathAttribute { name: "angle"; value: -64 }
                PathAttribute { name: "cardScale"; value: 0.6 }
                PathAttribute { name: "depth"; value: 0 }
                PathAttribute { name: "dim"; value: 0.75 }
            }

            delegate: Item {
                id: card

                required property int index
                required property string path
                required property string thumb
                required property string name
                required property bool video

                readonly property bool focused: PathView.isCurrentItem
                readonly property url thumbUrl: "file://" + thumb

                width: stage.cardW
                height: stage.cardH
                z: PathView.depth ?? 0
                scale: PathView.cardScale ?? 1

                transform: Rotation {
                    origin.x: card.width / 2
                    origin.y: card.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: card.PathView.angle ?? 0
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
                        cache: false
                        sourceSize: Qt.size(960, 540)
                        source: card.thumbUrl

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
                        active: card.video && card.focused && root.visible
                            && root.videoAllowed && !root.applying
                            && root.settledIndex === card.index
                        source: "WallpaperVideoPreview.qml"
                        onLoaded: item.path = card.path
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: card.PathView.dim ?? 0
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: face.radius
                    color: "transparent"
                    border.width: card.focused ? 2 : 1
                    border.color: card.focused ? Colors.primary : Qt.alpha(Colors.onSurface, 0.14)
                }

                // Značka videa, aby šla v bočních kartách rozeznat i bez popisku
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
                        if (card.focused) root.apply()
                        else view.currentIndex = card.index
                    }
                }
            }
        }

        // ------------------------------------------------------------ caption

        Column {
            id: caption
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.cy + stage.cardH / 2 + 34
            width: stage.cardW
            spacing: 10
            visible: shown.count > 0

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

        // Stavový řádek dole: buď nápověda kláves, nebo aktivní filtr
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
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
                    : [["← →", "browse"], ["Enter", "apply"], ["Ctrl R", "surprise me"],
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

    // -------------------------------------------------------------- launch

    // Po potvrzení se vybraná karta rozroste přes celou obrazovku; když je
    // nová tapeta na ploše, překryv se rozpustí (viz apply()).
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

        Image {
            id: launchFull
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(root.width, root.height)
            visible: status === Image.Ready
        }
    }

    ParallelAnimation {
        id: zoomAnim
        NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 100 }
        NumberAnimation { target: launch; property: "x"; from: stage.cx - stage.cardW / 2; to: 0; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: launch; property: "y"; from: stage.cy - stage.cardH / 2; to: 0; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: launch; property: "width"; from: stage.cardW; to: root.width; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: launch; property: "height"; from: stage.cardH; to: root.height; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: launch; property: "radius"; from: 14; to: 0; duration: 280 }
        onFinished: {
            root.zoomDone = true
            root.maybeReveal()
        }
    }

    SequentialAnimation {
        id: revealAnim
        ParallelAnimation {
            NumberAnimation { target: launch; property: "opacity"; from: 1; to: 0; duration: 160 }
            NumberAnimation { target: backdrop; property: "opacity"; from: 1; to: 0; duration: 160 }
        }
        ScriptAction {
            script: {
                revealTimeout.stop()
                root.visible = false
                launch.visible = false
                launch.opacity = 1
                launchFull.source = ""
                backdrop.opacity = 1
                root.applying = false
            }
        }
    }
}
