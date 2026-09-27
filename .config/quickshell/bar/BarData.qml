import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import QtQuick

// Data pro horní panel — jedna instance pro všechny monitory, ať se skripty
// nespouští dvakrát. Zdroje jsou schválně stejné jako u waybaru, aby panel
// ukazoval 1:1 totéž:
//   síť, VPN, GPU  → waybar-network.sh / waybar-vpn.sh / waybar-gpu.sh (JSON)
//   cava           → waybar-cava-stream.sh (řádek = sloupce ▁▂▃…)
//   CPU, paměť     → /proc/stat, /proc/meminfo (jako waybar cpu/memory)
//   teplota        → /sys/class/thermal/thermal_zone0 (výchozí zóna waybaru)
//   hlasitost      → PipeWire výchozí výstup (rp-audio ho drží stejný všude)
//   baterie        → UPower, jas → brightnessctl
//   přehrávač      → Mpris (bez proxy playerctld, stejně jako MediaWidget)
Item {
    id: root
    visible: false
    // false = žádný qs panel nesvítí (panelem je waybar) → nic nepollovat
    property bool active: true

    property var network: ({ text: "", tooltip: "", class: [] })
    property var vpn: ({ text: "", tooltip: "", class: [] })
    property var gpu: ({ text: "", tooltip: "" })
    property string cava: ""
    property int cpu: 0
    property var cores: []           // využití jednotlivých jader v %
    property string load: ""
    property int mem: 0
    property int temp: 0
    property int brightness: 0
    property bool hasBacklight: false

    // ── Zvuk
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    readonly property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string sinkName: sink ? (sink.description || sink.nickname || sink.name) : ""

    // ── Baterie
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery && battery.isPresent
    readonly property int batteryPct: hasBattery ? Math.round(battery.percentage * 100) : 0
    // Jen skutečné nabíjení (jako waybar format-charging); „nabito / nenabíjí se" ne
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging

    // Přehrávač: hrající má přednost. playerctld se vynechává úplně — po
    // zavření přehrávače na něm visí poslední stopa (viz README, Dashboard)
    readonly property var players: Mpris.players.values.filter(
        p => (p.dbusName || "").indexOf("playerctld") < 0)
    readonly property var player: {
        for (const p of players)
            if (p.playbackState === MprisPlaybackState.Playing) return p
        return players.length > 0 ? players[0] : null
    }
    readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"

    // Skript s JSON výstupem (waybar return-type json), opakovaně po intervalu
    component JsonPoll: Item {
        id: jp
        property var command
        property int interval: 2000
        signal result(var obj)
        Process {
            id: p
            command: jp.command
            running: root.active
            stdout: StdioCollector {
                onStreamFinished: {
                    const line = text.trim().split("\n").pop()
                    try { jp.result(JSON.parse(line)) } catch (e) {}
                }
            }
        }
        Timer { interval: jp.interval; running: root.active; repeat: true; onTriggered: p.running = true }
    }

    JsonPoll { command: [root.bin + "waybar-network.sh"]; interval: 2000; onResult: o => root.network = o }
    JsonPoll { command: [root.bin + "waybar-vpn.sh"]; interval: 5000; onResult: o => root.vpn = o }
    JsonPoll { command: [root.bin + "waybar-gpu.sh"]; interval: 3000; onResult: o => root.gpu = o }

    // cava běží pořád a posílá řádek za řádkem
    Process {
        id: cavaProc
        running: root.active
        command: [root.bin + "waybar-cava-stream.sh"]
        stdout: SplitParser { onRead: line => root.cava = line }
    }
    Timer { interval: 3000; running: root.active && !cavaProc.running; repeat: true; onTriggered: cavaProc.running = true }

    // CPU z rozdílu /proc/stat mezi dvěma čteními, paměť jako waybar (1 − avail/total)
    property var lastCpu: null
    FileView { id: statFile; path: "/proc/stat" }
    FileView { id: loadFile; path: "/proc/loadavg" }
    FileView { id: memFile; path: "/proc/meminfo" }
    FileView { id: tempFile; path: "/sys/class/thermal/thermal_zone0/temp" }
    Timer {
        interval: 2000; running: root.active; repeat: true; triggeredOnStart: true
        onTriggered: {
            statFile.reload(); memFile.reload(); tempFile.reload(); loadFile.reload()
            // řádek "cpu" = celkem, "cpuN" = jádra; využití z rozdílu proti minulému čtení
            const rows = statFile.text().split("\n").filter(l => /^cpu\d* /.test(l))
                .map(l => { const f = l.trim().split(/\s+/).slice(1).map(Number)
                            return { idle: f[3] + f[4], total: f.reduce((a, b) => a + b, 0) } })
            if (root.lastCpu && root.lastCpu.length === rows.length) {
                const pct = rows.map((r, i) => {
                    const dt = r.total - root.lastCpu[i].total, di = r.idle - root.lastCpu[i].idle
                    return dt > 0 ? Math.round(100 * (1 - di / dt)) : 0
                })
                root.cpu = pct[0]
                root.cores = pct.slice(1)
            }
            root.lastCpu = rows
            root.load = loadFile.text().split(" ").slice(0, 3).join("  ")
            const m = memFile.text()
            const kb = k => Number((m.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")) ?? [0, 0])[1])
            const tot = kb("MemTotal")
            if (tot > 0) root.mem = Math.round(100 * (1 - kb("MemAvailable") / tot))
            root.temp = Math.round(Number(tempFile.text().trim()) / 1000)
        }
    }

    // Jas: brightnessctl -m → "dev,class,cur,pct%,max"; OSD kláves ho obnoví hned
    Process {
        id: blProc
        command: ["brightnessctl", "--class=backlight", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",")
                root.hasBacklight = p.length >= 4
                if (root.hasBacklight) root.brightness = parseInt(p[3])
            }
        }
    }
    Timer { interval: 3000; running: root.active; repeat: true; onTriggered: blProc.running = true }
    function refreshBrightness() { blProc.running = false; blProc.running = true }
}
