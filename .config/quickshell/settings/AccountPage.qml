import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../Colors.js" as Colors

// Účet: jméno, skupiny, shell, poslední přihlášení, klíčenka. Změna hesla,
// jména a shellu se ptá na heslo a potřebuje terminál (passwd/chfn/chsh jsou
// interaktivní), proto jdou do kitty. Avatar záměrně ne.
Item {
    id: page
    required property var host

    property var acc: null

    Process {
        id: accProc
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/rp-sys", "account"]
        stdout: StdioCollector { onStreamFinished: { try { page.acc = JSON.parse(text) } catch (e) {} } }
    }

    function term(cmd) {
        Quickshell.execDetached(["kitty", "--hold", "-e", "bash", "-c", cmd + "; echo; echo 'Done — you can close this window.'"])
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
                height: 96
                Column {
                    anchors { left: parent.left; leftMargin: 26; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    SLabel { text: page.acc?.name || page.acc?.user || ""; font.pixelSize: 20; font.weight: Font.DemiBold }
                    SHint {
                        text: (page.acc?.user ?? "") + "  ·  uid " + (page.acc?.uid ?? "")
                            + (page.acc?.admin ? "  ·  administrator (wheel)" : "")
                    }
                }
            }

            SHeading { text: "SIGN-IN" }
            SRow {
                label: "Password"
                hint: "Also unlocks the keyring at login. Opens passwd in a terminal."
                SButton { icon: "󰌾"; text: "Change…"; onClicked: page.term("passwd") }
            }
            SRow {
                label: "Full name"
                hint: page.acc?.name ?? ""
                SButton { icon: "󰏫"; text: "Change…"; onClicked: page.term("read -rp 'New full name: ' n && chfn -f \"$n\"") }
            }
            SRow {
                label: "Login shell"
                hint: page.acc?.shell ?? ""
                SButton { icon: "󰆍"; text: "Change…"; onClicked: page.term("cat /etc/shells; echo; chsh") }
            }

            SHeading { text: "DETAILS" }
            SRow {
                label: "Groups"
                hint: (page.acc?.groups ?? []).join(", ")
            }
            SRow {
                label: "Home folder"
                hint: page.acc?.home ?? ""
                SButton { icon: "󰉋"; text: "Open"; onClicked: Quickshell.execDetached(["xdg-open", page.acc.home]) }
            }

            SHeading { text: "PASSWORDS & KEYS" }
            SRow {
                label: "Keyring"
                hint: "gnome-keyring stores Wi-Fi, browser and app secrets · " + (page.acc?.keyring ?? "")
                SButton {
                    visible: page.acc?.seahorse ?? false
                    icon: "󰌆"; text: "Open Passwords"
                    onClicked: Quickshell.execDetached(["seahorse"])
                }
            }

            SHeading { text: "RECENT SIGN-INS" }
            Repeater {
                model: page.acc?.logins ?? []
                SMono {
                    required property var modelData
                    width: col.width
                    leftPadding: 14
                    text: modelData.replace(/\s+/g, " ")
                    elide: Text.ElideRight
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
