import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: svc

    readonly property var list: server.trackedNotifications.values
    property var popups: []
    property var cfg: ({ position: "top-right", timeout: 6, max_visible: 5, dnd: false })
    property var history: []
    readonly property string home: Quickshell.env("HOME")

    function hidePopup(n) { popups = popups.filter(p => p !== n) }
    function clearAll() { for (const n of list.slice()) n.dismiss() }

    function activate(n) {
        const def = Array.from(n.actions).find(a => a.identifier === "default")
        if (def) def.invoke()
        if (!n.resident) n.dismiss()
    }

    function remember(n) {
        const entry = { id: n.id, app: n.appName, summary: n.summary,
                        body: n.body.replace(/<[^>]+>/g, ""), icon: n.appIcon,
                        urgency: n.urgency, desktop: n.desktopEntry, time: Date.now() }
        history = [entry].concat(history).slice(0, 200)
        historySave.restart()
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true
            svc.remember(n)
            n.closed.connect(() => svc.hidePopup(n))
            if (!svc.cfg.dnd || n.urgency === NotificationUrgency.Critical)
                svc.popups = [n].concat(svc.popups)
        }
    }

    FileView {
        path: svc.home + "/.config/niri-rice/notify.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { svc.cfg = Object.assign({}, svc.cfg, JSON.parse(text())) } catch (e) {}
            if (svc.cfg.dnd) svc.popups = svc.popups.filter(p => p.urgency === NotificationUrgency.Critical)
        }
    }

    FileView {
        id: historyFile
        blockLoading: true
        path: svc.home + "/.cache/niri-rice/notify-history.json"
        printErrors: false
        onLoaded: { try { svc.history = JSON.parse(text()) } catch (e) {} }
    }
    Timer { id: historySave; interval: 500; onTriggered: historyFile.setText(JSON.stringify(svc.history)) }
}
