import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Čas a jazyk: časové pásmo, synchronizace času, formát hodin ve waybaru,
// jazyk systému a regionální formáty. timedatectl/localectl si o heslo řeknou
// přes polkit samy (dialog PolkitDialog.qml); jazyk a formáty platí až po
// novém přihlášení. Chybějící locale `rp-sys set-locale` nejdřív vygeneruje.
Item {
    id: page
    required property var host

    property var t: null
    property var loc: null
    property var now: new Date()
    property string pendingLang: ""
    property string pendingFormats: ""

    function reload() {
        timeProc.running = false; timeProc.running = true
        locProc.running = false; locProc.running = true
    }
    function sys(args, title) {
        host.job.start(title, ["rp-sys"].concat(args), [], code => { page.reload(); if (code === 0) page.host.job.open = false })
    }

    Component.onCompleted: reload()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: page.now = new Date() }

    Process {
        id: timeProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "time"]
        stdout: StdioCollector { onStreamFinished: { try { page.t = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: locProc
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "locale"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.loc = JSON.parse(text)
                    page.pendingLang = page.loc.lang
                    page.pendingFormats = page.loc.formats
                } catch (e) {}
            }
        }
    }

    // Formáty hodin ve waybaru (strftime ve {:…}); začínají ikonou hodin (U+F017),
    // bez ní by výběr formátu ikonu z waybaru smazal
    readonly property var clockFormats: [
        { f: "  {:%d.%m. %H:%M}", label: "26.09. 14:30" },
        { f: "  {:%H:%M}", label: "14:30" },
        { f: "  {:%H:%M:%S}", label: "14:30:05" },
        { f: "  {:%a %d.%m. %H:%M}", label: "Sat 26.09. 14:30" },
        { f: "  {:%A %d. %B %H:%M}", label: "Saturday 26. September 14:30" },
        { f: "  {:%I:%M %p}", label: "02:30 PM" },
        { f: "  {:%Y-%m-%d %H:%M}", label: "2026-09-26 14:30" },
    ]

    readonly property var localeChoices: {
        if (!loc) return []
        const all = loc.available.length ? loc.available : loc.generated
        return Array.from(new Set(["C.UTF-8"].concat(loc.generated).concat(all))).sort()
    }

    function localeLabel(l) {
        const names = { en_US: "English (US)", en_GB: "English (UK)", cs_CZ: "Čeština", sk_SK: "Slovenčina", de_DE: "Deutsch",
                        fr_FR: "Français", es_ES: "Español", it_IT: "Italiano", pl_PL: "Polski", ja_JP: "日本語", C: "C (plain)" }
        const base = l.replace(/\.UTF-8$/, "")
        return (names[base] ? names[base] + "  ·  " : "") + l + (loc && loc.generated.includes(l) ? "" : "  (will be generated)")
    }

    SWheel { flick: flick }
    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SScrollBar {}

        Column {
            id: col
            width: flick.width - 12
            spacing: 2
            topPadding: 8

            SCard {
                width: parent.width
                height: 100
                Column {
                    anchors { left: parent.left; leftMargin: 26; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel {
                        text: Qt.formatTime(page.now, "HH:mm:ss")
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                    }
                    SHint { text: Qt.formatDate(page.now, "dddd d. MMMM yyyy") + "  ·  " + (page.t?.timezone ?? "") }
                }
                Column {
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SHint {
                        anchors.right: parent.right
                        text: page.t?.synced ? "󰄬 Synced with internet time" : "Not synced"
                        color: page.t?.synced ? Colors.primary : Colors.tertiary
                    }
                }
            }

            SHeading { text: "DATE & TIME" }
            SRow {
                label: "Time zone"
                hint: "Asks for your password."
                SDropdown {
                    width: 280
                    options: page.t?.zones ?? []
                    current: page.t?.timezone ?? ""
                    onPicked: v => page.sys(["set-timezone", v], "Time zone → " + v)
                }
            }
            SRow {
                label: "Set time automatically"
                hint: "Keeps the clock in sync over the network (systemd-timesyncd)."
                SToggle {
                    checked: page.t?.ntp ?? false
                    onToggled: v => page.sys(["set-ntp", v ? "true" : "false"], "Network time " + (v ? "on" : "off"))
                }
            }
            SRow {
                label: "Clock in the bar"
                hint: "Format of waybar's clock."
                SDropdown {
                    width: 280
                    options: page.clockFormats.map(c => c.f)
                    labels: page.clockFormats.map(c => c.label)
                    current: page.t?.clockFormat ?? ""
                    displayText: page.clockFormats.find(c => c.f === page.t?.clockFormat)?.label ?? (page.t?.clockFormat ?? "")
                    onPicked: v => page.sys(["set-clock", v], "Bar clock format")
                }
            }

            SHeading { text: "LANGUAGE & REGION" }
            SRow {
                label: "System language"
                hint: "Language of menus and messages in apps that are translated."
                SDropdown {
                    width: 320
                    options: page.localeChoices
                    labels: page.localeChoices.map(l => page.localeLabel(l))
                    current: page.pendingLang
                    displayText: page.localeLabel(page.pendingLang)
                    onPicked: v => page.pendingLang = v
                }
            }
            SRow {
                label: "Regional formats"
                hint: "Dates, numbers, currency, paper size and units. E.g. English language with Czech formats."
                SDropdown {
                    width: 320
                    options: page.localeChoices
                    labels: page.localeChoices.map(l => page.localeLabel(l))
                    current: page.pendingFormats
                    displayText: page.localeLabel(page.pendingFormats)
                    onPicked: v => page.pendingFormats = v
                }
            }
            SRow {
                visible: page.loc !== null && (page.pendingLang !== page.loc.lang || page.pendingFormats !== page.loc.formats)
                label: "Apply language and formats"
                hint: "Generates missing locales and saves them system-wide; log out and back in to see it everywhere."
                SButton {
                    icon: "󰄬"; text: "Apply"
                    busy: page.host.job.running
                    onClicked: page.host.job.start("Language " + page.pendingLang + ", formats " + page.pendingFormats,
                        ["rp-sys", "set-locale", page.pendingLang, page.pendingFormats], [], code => page.reload())
                }
            }
            SRow {
                label: "Keyboard layouts"
                hint: "Layouts and the switching key are on the Keyboard page."
                SButton { icon: "󰁔"; text: "Keyboard"; onClicked: page.host.goTo("keyboard") }
            }
        }
    }
}
