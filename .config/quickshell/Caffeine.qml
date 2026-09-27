import Quickshell
import Quickshell.Wayland
import QtQuick

// Caffeine: dokud je zapnutý, obrazovka nezhasne a swayidle nezamkne.
// idle-inhibit protokol potřebuje namapovaný povrch, proto drží neviditelné
// 1×1 okno na spodní vrstvě (bez vstupu, nezabírá místo). Stav přežije
// reload quickshellu, ne restart.
Scope {
    id: root
    property alias on: persist.on
    function toggle() { persist.on = !persist.on }

    PersistentProperties {
        id: persist
        reloadableId: "caffeine"
        property bool on: false
    }

    LazyLoader {
        active: persist.on
        PanelWindow {
            id: holder
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            anchors { left: true; top: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rp-caffeine"
            mask: Region {}
            IdleInhibitor { window: holder; enabled: true }
        }
    }
}
