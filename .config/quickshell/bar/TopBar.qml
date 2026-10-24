import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects
import "../Colors.js" as Colors

PanelWindow {
    id: bar

    required property var modelData
    required property var barData
    required property var niri
    screen: modelData

    readonly property string output: modelData.name
    readonly property var hiddenTray: ["nm-applet"]
    readonly property int barHeight: 36
    readonly property int pillHeight: 28
    readonly property int edge: 8
    readonly property int gap: 6
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    color: "transparent"
    anchors { left: true; right: true; top: true }
    implicitHeight: barHeight
    exclusiveZone: barHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rp-bar"

    BackgroundEffect.blurRegion: Region { item: barBg }
    Rectangle {
        id: barBg
        anchors.fill: parent
        color: Qt.alpha(Colors.surface, 0.72)
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Qt.alpha(Colors.outlineVariant, 0.6)
        }
    }

    function anchorFor(key) {
        const it = ({ network: netItem, audio: volItem, power: batt })[key]
        return it && it.visible ? it.mapToItem(null, it.width / 2, 0).x : -1
    }

    function sh(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    readonly property var workspaces: {
        if (!niri) return []
        niri.revision
        return Object.values(niri.workspaces)
            .filter(w => w.output === output)
            .filter(w => w.is_active || Object.values(niri.windows).some(x => x.workspace_id === w.id))
            .sort((a, b) => a.idx - b.idx)
    }
    readonly property var activeWindow: {
        if (!niri) return null
        niri.revision
        const ws = Object.values(niri.workspaces).find(w => w.output === output && w.is_active)
        return ws && ws.active_window_id != null ? niri.windows[ws.active_window_id] : null
    }
    readonly property string windowTitle: {
        const t = activeWindow ? (activeWindow.title || activeWindow.app_id || "") : ""
        return t.length > 50 ? t.slice(0, 49) + "…" : t
    }
    readonly property string windowApp: activeWindow?.app_id ? niri.appName(activeWindow.app_id) : ""

    component Pill: Rectangle {
        id: pill
        default property alias content: row.data
        property color tint: Colors.surfaceContainerHigh
        property real tintAlpha: 0.9
        property int pad: 10
        property bool bare: false
        property bool clickable: false
        property int buttons: Qt.LeftButton
        readonly property bool hovered: pillArea.containsMouse
        signal clicked()
        signal buttonClicked(int button)
        implicitWidth: row.implicitWidth + 2 * pad
        width: implicitWidth
        height: bar.pillHeight
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        radius: height / 2
        color: bare ? "transparent" : Qt.alpha(tint, tintAlpha)
        border.width: bare ? 0 : 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.7)
        MouseArea {
            id: pillArea
            anchors.fill: parent
            enabled: pill.clickable
            hoverEnabled: true
            acceptedButtons: pill.buttons
            cursorShape: Qt.PointingHandCursor
            onClicked: e => { if (e.button === Qt.LeftButton) pill.clicked(); pill.buttonClicked(e.button) }
        }
        Row {
            id: row
            anchors.centerIn: parent
            height: parent.height
            spacing: 10
        }
    }

    component Item_: Text {
        id: it
        property string tip: ""
        property string icon: ""
        property string value: ""
        property color iconColor: Colors.primary
        property color baseColor: Colors.onSurface
        textFormat: icon !== "" ? Text.StyledText : Text.PlainText
        text: icon !== "" ? "<font color=\"" + iconColor + "\">" + icon + "</font>&nbsp;" + value : value
        property bool clickable: false
        signal leftClicked()
        signal rightClicked()
        signal middleClicked()
        signal wheel(int dir)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font.family: bar.fontFamily
        font.pixelSize: 13
        color: area.containsMouse && clickable ? Colors.primary : baseColor
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: it.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: e => {
                if (e.button === Qt.LeftButton) it.leftClicked()
                else if (e.button === Qt.RightButton) it.rightClicked()
                else it.middleClicked()
            }
            onWheel: e => it.wheel(e.angleDelta.y > 0 ? 1 : -1)
        }
        BarTooltip { target: it; text: it.tip; wanted: area.containsMouse && it.tip !== "" }
    }

    TrayMenu { id: trayMenu }
    ClockPopup { id: clockPopup; target: center; targetHovered: clockHover.hovered }

    Row {
        id: left
        anchors { left: parent.left; leftMargin: bar.edge; verticalCenter: parent.verticalCenter }
        spacing: bar.gap
        width: Math.min(implicitWidth, center.x - bar.gap - bar.edge)
        clip: true

        Pill {
            id: wsPill
            pad: 3
            readonly property int cell: 22
            readonly property int activeIndex: bar.workspaces.findIndex(w => w.is_active)

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: wsRow.width
                height: wsPill.cell

                Rectangle {
                    visible: wsPill.activeIndex >= 0
                    width: wsPill.cell; height: wsPill.cell
                    radius: wsPill.cell / 2
                    color: Qt.alpha(Colors.primary, 0.22)
                    x: Math.max(0, wsPill.activeIndex) * (wsPill.cell + wsRow.spacing)
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                }

                Row {
                    id: wsRow
                    spacing: 2
                    Repeater {
                        model: bar.workspaces
                        Item {
                            required property var modelData
                            readonly property bool active: modelData.is_active
                            width: wsPill.cell; height: wsPill.cell

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: wsHover.containsMouse && !parent.active ? Qt.alpha(Colors.primary, 0.14) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.active ? 8 : 6
                                height: width
                                radius: width / 2
                                color: parent.active ? Colors.primary
                                    : wsHover.containsMouse ? Colors.primary : Qt.alpha(Colors.onSurfaceVariant, 0.5)
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                id: wsHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bar.sh("niri msg action focus-monitor " + bar.output
                                                  + " && niri msg action focus-workspace " + modelData.idx)
                            }
                        }
                    }
                }
            }
        }

        Pill {
            id: titlePill
            visible: bar.windowTitle !== ""
            HoverHandler { id: titleHover }
            BarTooltip { target: titlePill; text: bar.windowApp; wanted: titleHover.hovered }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.windowTitle
                font.family: bar.fontFamily
                font.pixelSize: 13
                color: Colors.onSurface
            }
        }

        Text {
            visible: bar.barData.cava !== ""
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 2
            text: bar.barData.cava
            font.family: bar.fontFamily
            font.pixelSize: 12
            color: Colors.primary
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.85; shadowBlur: 0.5; shadowVerticalOffset: 1 }
        }
        Pill {
            id: mediaPill
            readonly property var p: bar.barData.player
            readonly property string track: {
                if (!p) return ""
                const a = p.trackArtist || "", t = p.trackTitle || p.identity || ""
                return a !== "" && t !== "" ? a + " – " + t : a + t
            }
            visible: track !== ""
            clickable: true
            opacity: bar.barData.playing ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: 150 } }
            buttons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onButtonClicked: b => {
                const p = mediaPill.p
                if (!p) return
                if (b === Qt.RightButton) bar.sh(bar.bin + "rp-shell dashboard open")
                else if (b === Qt.MiddleButton) { if (p.canGoNext) p.next() }
                else if (p.canTogglePlaying) p.togglePlaying()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.barData.playing ? "\u{f03e4}" : "\u{f040a}"
                font.family: bar.fontFamily
                font.pixelSize: 13
                color: Colors.primary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 280)
                elide: Text.ElideRight
                text: mediaPill.track
                font.family: bar.fontFamily
                font.pixelSize: 13
                color: Colors.onSurface
            }
        }
    }

    property var now: new Date()
    FileView {
        id: rpSettings
        path: Quickshell.env("HOME") + "/.config/niri-rice/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property string clockFormat: {
        try { return JSON.parse(rpSettings.text())["bar.clock"] || "dd.MM. HH:mm" } catch (e) { return "dd.MM. HH:mm" }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.now = new Date() }

    Pill {
        id: center
        anchors.centerIn: parent
        HoverHandler { id: clockHover }
        pad: 14
        clickable: true
        onClicked: clockPopup.toggle()
        Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.StyledText
            text: "<font color=\"" + Colors.primary + "\">\uf017</font>&nbsp;" + Qt.formatDateTime(bar.now, bar.clockFormat)
            font.family: bar.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Colors.onSurface
        }
    }

    Row {
        id: right
        anchors { right: parent.right; rightMargin: bar.edge; verticalCenter: parent.verticalCenter }
        spacing: bar.gap
        layoutDirection: Qt.LeftToRight
        width: Math.min(implicitWidth, bar.width - (center.x + center.width) - bar.gap - bar.edge)
        clip: true

        Pill {
            bare: true
            pad: 4
            Item_ {
                id: netItem
                value: bar.barData.network.text ?? ""
                tip: bar.barData.network.tooltip ?? ""
                baseColor: Colors.tertiary
                font.pixelSize: 12
                clickable: true
                onLeftClicked: bar.sh(bar.bin + "rp-shell network toggle")
            }
            Item_ {
                visible: (bar.barData.vpn.text ?? "") !== ""
                value: bar.barData.vpn.text ?? ""
                tip: bar.barData.vpn.tooltip ?? ""
                baseColor: (bar.barData.vpn.class ?? []).includes("active") ? Colors.tertiary : Qt.alpha(Colors.tertiary, 0.4)
                font.pixelSize: 12
                clickable: true
                onLeftClicked: bar.sh("command -v protonvpn-app >/dev/null && exec protonvpn-app || exec " + bar.bin + "rp-shell network toggle")
            }
        }

        Pill {
            Item_ {
                icon: "\uf4bc"; value: bar.barData.cpu + "%"; iconColor: Colors.secondary
                tip: {
                    const c = bar.barData.cores
                    let lines = ["CPU " + bar.barData.cpu + " %   ·   load " + bar.barData.load, ""]
                    const half = Math.ceil(c.length / 2)
                    for (let i = 0; i < half; i++) {
                        const a = ("core " + i).padEnd(8) + String(c[i]).padStart(3) + " %"
                        const j = i + half
                        lines.push(j < c.length ? a + "     " + ("core " + j).padEnd(8) + String(c[j]).padStart(3) + " %" : a)
                    }
                    return lines.join("\n")
                }
            }
            Item_ {
                readonly property string raw: bar.barData.gpu.text ?? ""
                icon: raw.split(" ")[0]; value: raw.split(" ").slice(1).join(" ")
                iconColor: Colors.secondary
                tip: bar.barData.gpu.tooltip ?? ""
            }
            Item_ { icon: "\uefc5"; value: bar.barData.mem + "%"; iconColor: Colors.secondary; tip: bar.barData.memTip }
            Item_ {
                icon: "\uf2c9"; value: bar.barData.temp + "°C"
                tip: bar.barData.tempTip
                iconColor: bar.barData.temp >= 85 ? Colors.errorColor : Colors.tertiary
                baseColor: bar.barData.temp >= 85 ? Colors.errorColor : Colors.onSurface
            }
        }

        Pill {
            Item_ {
                id: volItem
                icon: bar.barData.muted ? "\ueee8" : (bar.barData.volume < 34 ? "\uf026" : bar.barData.volume < 67 ? "\uf027" : "\uf028")
                value: bar.barData.muted ? "" : bar.barData.volume + "%"
                iconColor: bar.barData.muted ? Qt.alpha(Colors.onSurfaceVariant, 0.5) : Colors.onSurfaceVariant
                tip: bar.barData.sinkName + "\n" + bar.barData.volume + " %"
                clickable: true
                onLeftClicked: bar.sh(bar.bin + "rp-shell audio toggle")
                onRightClicked: bar.sh(bar.bin + "rp-shell settings sound")
                onMiddleClicked: bar.sh("rp-audio mute")
                onWheel: dir => bar.sh("rp-audio volume " + (dir > 0 ? "up" : "down"))
            }
            Item_ {
                id: batt
                visible: bar.barData.hasBattery
                readonly property int pct: bar.barData.batteryPct
                readonly property bool low: !bar.barData.charging && pct <= 30
                icon: bar.barData.charging ? "\uf0e7" : ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"][Math.min(4, Math.floor(pct / 20))]
                value: pct + "%"
                iconColor: low ? Colors.errorColor : Colors.tertiary
                tip: pct + " %" + (bar.barData.charging ? " · charging" : "") + "\nClick to switch power mode"
                baseColor: low ? Colors.errorColor : Colors.onSurface
                clickable: true
                onLeftClicked: bar.sh(bar.bin + "rp-shell power toggle")
                SequentialAnimation on opacity {
                    running: batt.low
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) batt.opacity = 1
                    NumberAnimation { to: 0.4; duration: batt.pct <= 15 ? 400 : 750 }
                    NumberAnimation { to: 1; duration: batt.pct <= 15 ? 400 : 750 }
                }
            }
            Item_ {
                icon: String.fromCodePoint(0xf00df); value: bar.barData.brightness + "%"; iconColor: Colors.onSurfaceVariant
                onWheel: dir => { bar.sh(bar.bin + "brightness-osd.sh " + (dir > 0 ? "up" : "down")); bar.barData.refreshBrightness() }
            }
        }

        Pill {
            visible: SystemTray.items.values.some(i => !bar.hiddenTray.includes(i.id))
            pad: 10
            Repeater {
                model: SystemTray.items
                Item {
                    id: ti
                    required property SystemTrayItem modelData
                    visible: !bar.hiddenTray.includes(modelData.id)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    readonly property bool symbolic: (ti.modelData.icon || "").indexOf("symbolic") >= 0
                    IconImage {
                        id: trayIcon
                        anchors.fill: parent
                        visible: !ti.symbolic
                        source: {
                            const ic = ti.modelData.icon
                            if (!ic) return ""
                            return ic.startsWith("/") ? "file://" + ic : ic
                        }
                    }
                    MultiEffect {
                        visible: ti.symbolic
                        anchors.fill: parent
                        source: trayIcon
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: Colors.onSurface
                    }
                    Rectangle {
                        visible: trayIcon.status !== Image.Ready
                        anchors.fill: parent
                        radius: 5
                        color: Qt.alpha(Colors.primary, 0.18)
                        Text {
                            anchors.centerIn: parent
                            text: (ti.modelData.title || ti.modelData.id || "?").charAt(0).toUpperCase()
                            font.family: bar.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Colors.primary
                        }
                    }
                    MouseArea {
                        id: tiArea
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: e => {
                            if (e.button === Qt.LeftButton && !ti.modelData.onlyMenu) ti.modelData.activate()
                            else if (e.button === Qt.MiddleButton) ti.modelData.secondaryActivate()
                            else if (ti.modelData.hasMenu) trayMenu.toggleAt(ti, ti.modelData.menu, ti.modelData.tooltipTitle || ti.modelData.title)
                        }
                        onWheel: e => ti.modelData.scroll(e.angleDelta.y, false)
                    }
                    BarTooltip { target: ti; text: ti.modelData.tooltipTitle || ti.modelData.title; wanted: tiArea.containsMouse && !(trayMenu.visible && trayMenu.owner === ti) }
                }
            }
        }

        Pill {
            tint: hovered ? Colors.errorColor : Colors.surfaceContainerHigh
            tintAlpha: hovered ? 0.3 : 0.9
            pad: 9
            border.color: hovered ? Qt.alpha(Colors.errorColor, 0.7) : Qt.alpha(Colors.outlineVariant, 0.7)
            Behavior on color { ColorAnimation { duration: 150 } }
            clickable: true
            onClicked: bar.sh(bar.bin + "rp-shell dashboard toggle")
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf011"
                font.family: bar.fontFamily
                font.pixelSize: 15
                color: Colors.errorColor
            }
        }
    }
}
