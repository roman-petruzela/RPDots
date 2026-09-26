import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects
import "../Colors.js" as Colors

// Horní panel (náhrada waybaru) — jeden na monitor. Rozložení a chování 1:1
// s waybarem (viz .config/waybar/config.jsonc), vzhled sjednocený s okny
// ricu (Settings, flyouty): stejný font, barvy a zaoblení.
//
//   vlevo   workspacy tohohle monitoru · okno zaměřené na tomhle monitoru · cava
//   střed   hodiny a datum — vždy přesně uprostřed; levá/pravá strana se
//           zkrátí (ořízne), nikdy hodiny neodsunou
//   vpravo  síť (↓ ↑, VPN) · CPU GPU paměť teplota · zvuk baterie jas · tray · napájení
//
// Data dodává sdílený BarData, stav niri sdílený NiriState (shell.qml).
PanelWindow {
    id: bar

    required property var modelData
    required property var barData
    required property var niri
    screen: modelData

    readonly property string output: modelData.name
    readonly property int barHeight: 36          // stejně jako waybar
    readonly property int pillHeight: 28
    readonly property int edge: 8                // okraj panelu vlevo i vpravo (symetrie)
    readonly property int gap: 6                 // mezera mezi pilulkami
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    color: "transparent"
    anchors { left: true; right: true; top: true }
    implicitHeight: barHeight
    exclusiveZone: barHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rp-bar"

    function sh(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    // ── Stav niri pro tenhle monitor
    readonly property var workspaces: {
        if (!niri) return []
        niri.revision
        return Object.values(niri.workspaces)
            .filter(w => w.output === output)
            // jako waybar hide-empty: prázdné pryč, kromě aktivního
            .filter(w => w.is_active || Object.values(niri.windows).some(x => x.workspace_id === w.id))
            .sort((a, b) => a.idx - b.idx)
    }
    readonly property string windowTitle: {
        if (!niri) return ""
        niri.revision
        const ws = Object.values(niri.workspaces).find(w => w.output === output && w.is_active)
        const win = ws && ws.active_window_id != null ? niri.windows[ws.active_window_id] : null
        const t = win ? (win.title || win.app_id || "") : ""
        return t.length > 50 ? t.slice(0, 49) + "…" : t      // max-length 50 jako waybar
    }

    // ── Společné prvky
    // Pilulka: stejný podklad pro všechny skupiny, obsah v řadě na střed
    component Pill: Rectangle {
        id: pill
        default property alias content: row.data
        property color tint: Colors.surfaceContainer
        property real tintAlpha: 0.72
        property int pad: 10
        property bool clickable: false
        readonly property bool hovered: pillArea.containsMouse
        signal clicked()
        implicitWidth: row.implicitWidth + 2 * pad
        width: implicitWidth
        height: bar.pillHeight
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        radius: height / 2
        color: Qt.alpha(tint, tintAlpha)
        border.width: 1
        border.color: Qt.alpha(Colors.outlineVariant, 0.55)
        MouseArea {
            id: pillArea
            anchors.fill: parent
            enabled: pill.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
        Row {
            id: row
            anchors.centerIn: parent
            height: parent.height
            spacing: 10
        }
    }

    // Text modulu (ikona + hodnota), svisle na středu, s hover/kliky a tooltipem
    component Item_: Text {
        id: it
        property string tip: ""
        property color baseColor: Colors.onSurface
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
        BarTooltip { target: it; text: it.tip; show: area.containsMouse && it.tip !== "" }
    }

    TrayMenu { id: trayMenu }

    // ═══ Levá strana ═════════════════════════════════════════════════════
    Row {
        id: left
        anchors { left: parent.left; leftMargin: bar.edge; verticalCenter: parent.verticalCenter }
        spacing: bar.gap
        // Nikdy nezasáhne do hodin: šířka omezená do poloviny minus hodiny
        width: Math.min(implicitWidth, center.x - bar.gap - bar.edge)
        clip: true

        // Workspacy tohohle monitoru: čtverce stejné šířky i výšky, zvýraznění
        // aktivního k němu plynule přejede, tečka aktivního se zvětší
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
                    color: Qt.alpha(Colors.primaryContainer, 0.95)
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
                                color: parent.active ? Colors.onPrimaryContainer
                                    : wsHover.containsMouse ? Colors.primary : Qt.alpha(Colors.onSurfaceVariant, 0.5)
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                id: wsHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // focus-workspace bere pořadí na zaměřeném monitoru — proto nejdřív monitor
                                onClicked: bar.sh("niri msg action focus-monitor " + bar.output
                                                  + " && niri msg action focus-workspace " + modelData.idx)
                            }
                        }
                    }
                }
            }
        }

        // Okno zaměřené na tomhle monitoru
        Pill {
            visible: bar.windowTitle !== ""
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.windowTitle
                font.family: bar.fontFamily
                font.pixelSize: 13
                color: Colors.onSurface
            }
        }

        // cava — i potichu (ploché sloupce), ať se panel při pauze nepřeskládá
        Text {
            visible: bar.barData.cava !== ""
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 2
            text: bar.barData.cava
            font.family: bar.fontFamily
            font.pixelSize: 12
            color: Colors.primary
        }
    }

    // ═══ Střed: hodiny ═══════════════════════════════════════════════════
    property var now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.now = new Date() }

    Pill {
        id: center
        anchors.centerIn: parent
        tint: Colors.primaryContainer
        tintAlpha: 0.65
        pad: 14
        border.color: Qt.alpha(Colors.primary, 0.45)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf017 " + Qt.formatDateTime(bar.now, "dd.MM. HH:mm")
            font.family: bar.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
            font.letterSpacing: 0.5
            color: Colors.onPrimaryContainer
        }
    }

    // ═══ Pravá strana ════════════════════════════════════════════════════
    Row {
        id: right
        anchors { right: parent.right; rightMargin: bar.edge; verticalCenter: parent.verticalCenter }
        spacing: bar.gap
        layoutDirection: Qt.LeftToRight
        width: Math.min(implicitWidth, bar.width - (center.x + center.width) - bar.gap - bar.edge)
        clip: true

        // Síť + VPN — bez podkladu, jen text (jako cava)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            height: bar.pillHeight
            spacing: 10
            rightPadding: 4
            Item_ {
                text: bar.barData.network.text ?? ""
                tip: bar.barData.network.tooltip ?? ""
                baseColor: Colors.tertiary
                font.pixelSize: 12
                clickable: true
                onLeftClicked: bar.sh(bar.bin + "rp-shell network toggle")
            }
            Item_ {
                visible: (bar.barData.vpn.text ?? "") !== ""
                text: bar.barData.vpn.text ?? ""
                tip: bar.barData.vpn.tooltip ?? ""
                baseColor: (bar.barData.vpn.class ?? []).includes("active") ? Colors.tertiary : Qt.alpha(Colors.tertiary, 0.4)
                font.pixelSize: 12
                clickable: true
                onLeftClicked: bar.sh(bar.bin + "protonvpn-app")
            }
        }

        // Hardware
        Pill {
            Item_ {
                text: "\uf4bc " + bar.barData.cpu + "%"
                baseColor: Colors.secondary
                tip: {
                    const c = bar.barData.cores
                    let lines = ["CPU " + bar.barData.cpu + " %   ·   load " + bar.barData.load, ""]
                    // jádra ve dvou sloupcích
                    const half = Math.ceil(c.length / 2)
                    for (let i = 0; i < half; i++) {
                        const a = ("core " + i).padEnd(8) + String(c[i]).padStart(3) + " %"
                        const j = i + half
                        lines.push(j < c.length ? a + "     " + ("core " + j).padEnd(8) + String(c[j]).padStart(3) + " %" : a)
                    }
                    return lines.join("\n")
                }
            }
            Item_ { text: bar.barData.gpu.text ?? ""; tip: bar.barData.gpu.tooltip ?? ""; baseColor: Colors.secondary }
            Item_ { text: "\uefc5 " + bar.barData.mem + "%"; baseColor: Colors.secondary }
            Item_ {
                text: "\uf2c9 " + bar.barData.temp + "°C"
                baseColor: bar.barData.temp >= 85 ? Colors.errorColor : Colors.tertiary   // critical-threshold 85
            }
        }

        // Zvuk, baterie, jas
        Pill {
            Item_ {
                text: bar.barData.muted ? "\ueee8 " : (bar.barData.volume < 34 ? "\uf026" : bar.barData.volume < 67 ? "\uf027" : "\uf028") + " " + bar.barData.volume + "%"
                tip: bar.barData.sinkName + "\n" + bar.barData.volume + " %"
                baseColor: bar.barData.muted ? Qt.alpha(Colors.onSurfaceVariant, 0.35) : Colors.onSurfaceVariant
                clickable: true
                onLeftClicked: bar.sh(bar.bin + "rp-shell audio toggle")
                onRightClicked: bar.sh(bar.bin + "rp-shell settings sound")
                onMiddleClicked: bar.sh(bar.bin + "rp-audio mute")
                onWheel: dir => bar.sh(bar.bin + "rp-audio volume " + (dir > 0 ? "up" : "down"))
            }
            Item_ {
                id: batt
                visible: bar.barData.hasBattery
                readonly property int pct: bar.barData.batteryPct
                readonly property bool low: !bar.barData.charging && pct <= 30
                text: (bar.barData.charging ? "\uf0e7" : ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"][Math.min(4, Math.floor(pct / 20))]) + " " + pct + "%"
                tip: pct + " %" + (bar.barData.charging ? " · charging" : "") + "\nClick to switch power mode"
                baseColor: low ? Colors.errorColor : Colors.tertiary
                clickable: true
                onLeftClicked: bar.sh(bar.bin + "rp-shell power toggle")
                // warning 30 % bliká pomaleji, critical 15 % rychleji (jako waybar)
                SequentialAnimation on opacity {
                    running: batt.low
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) batt.opacity = 1
                    NumberAnimation { to: 0.4; duration: batt.pct <= 15 ? 400 : 750 }
                    NumberAnimation { to: 1; duration: batt.pct <= 15 ? 400 : 750 }
                }
            }
            Item_ {
                text: "󰃟 " + bar.barData.brightness + "%"
                baseColor: Colors.onSurfaceVariant
                onWheel: dir => { bar.sh(bar.bin + "brightness-osd.sh " + (dir > 0 ? "up" : "down")); bar.barData.refreshBrightness() }
            }
        }

        // Tray
        Pill {
            visible: SystemTray.items.values.length > 0
            pad: 10
            Repeater {
                model: SystemTray.items
                Item {
                    id: ti
                    required property SystemTrayItem modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    readonly property bool symbolic: (ti.modelData.icon || "").indexOf("symbolic") >= 0
                    IconImage {
                        id: trayIcon
                        anchors.fill: parent
                        // Symbolické ikony (Easy Effects…) jsou černé šablony — GTK je
                        // přebarví podle textu, tady to udělá MultiEffect níž
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
                    // Ikona, kterou téma nemá (Steam posílá vlastní jméno) → první písmeno
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
                            // vlastní QML menu (display() by chtělo QApplication režim)
                            else if (ti.modelData.hasMenu) trayMenu.openAt(ti, ti.modelData.menu)
                        }
                        onWheel: e => ti.modelData.scroll(e.angleDelta.y, false)
                    }
                    BarTooltip { target: ti; text: ti.modelData.tooltipTitle || ti.modelData.title; show: tiArea.containsMouse }
                }
            }
        }

        // Napájení → dashboard
        Pill {
            tint: Colors.errorColor
            tintAlpha: hovered ? 0.4 : 0.26
            pad: 9
            border.color: Qt.alpha(Colors.errorColor, hovered ? 0.65 : 0.35)
            Behavior on tintAlpha { NumberAnimation { duration: 150 } }
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
