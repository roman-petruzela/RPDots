#!/usr/bin/env bash
set -euo pipefail
# Řídí mpvpaper pro video tapety.
#
# Návrh: awww zůstává jediným zdrojem pravdy pro statickou vrstvu a vždy zobrazuje
# ~/.local/share/wallpapers/current, což je i u videa obrázek (jeho první snímek).
# Díky tomu funguje matugen, healthcheck i přechodové efekty beze změny.
# mpvpaper se pak jen položí navrch a video se rozhýbe — přechod vypadá stejně
# jako u obrázků.

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
CURRENT_VIDEO="$STATE_DIR/current-video"

# Existuje = video vrstva je dočasně potlačená (rp-power battery/gaming). Statická
# awww vrstva zůstane, takže tapeta nezmizí — jen zamrzne na prvním snímku.
# Guard sedí tady, a ne ve volajícím, aby ho respektoval i healthcheck timer,
# který by jinak video do dvou minut nahodil zpátky.
VIDEO_INHIBIT="$STATE_DIR/video-inhibit"

# Vrstva mpvpaperu. Background — stejná jako awww — protože niri zahrnuje do
# backdropu (place-within-backdrop, pravidlo v config.kdl) jen tuhle vrstvu,
# a jen z backdropu bere xray blur oken (kitty, fuzzel, mako). V Bottom by
# video pod rozmazanými okny nebylo vidět, blur by ukazoval statický snímek.
# V rámci jedné vrstvy kreslí niri později namapovaný povrch navrch, proto
# healthcheck po restartu awww-daemonu restartuje i video (sync, ne ensure).
LAYER="${WALL_VIDEO_LAYER:-background}"

# no-audio       — tapeta nikdy nehraje zvuk
# loop-file=inf  — nekonečná smyčka
# hwdec          — hardwarový dekód, jinak by 60fps 4K žralo CPU
# profile=fast   — mpv defaultně škáluje přehraný snímek na výstup drahým
#                  polárním filtrem (ewa_lanczos apod.); to běží každý frame na
#                  iGPU, která si ho dělí se zbytkem DE. U 4K tapety na FHD
#                  výstupu je tenhle scale-down krok dost velký, aby to sekalo
#                  celý desktop, i když samotný dekód je hardwarový. profile=fast
#                  je vestavěný mpv profil (bilineární scale/cscale/dscale,
#                  vypnutý dither/deband/sigmoid-upscaling) přesně pro tenhle případ.
# vo=libmpv      — mpvpaper vyžaduje
MPV_OPTS="${WALL_VIDEO_MPV_OPTS:-no-audio loop-file=inf hwdec=auto-safe profile=fast video-sync=display-resample panscan=1.0}"

have_mpvpaper() { command -v mpvpaper >/dev/null 2>&1; }

# Dá vědět pickeru (WallpaperPicker.qml), že nová tapeta je opravdu na ploše —
# awww ji už zobrazil a případné staré video nad ní je pryč. Picker do té doby
# drží přes obrazovku svůj náhled, aby přepnutí vypadalo okamžitě.
SHOWN_FILE="$STATE_DIR/wallpaper-shown"
mark_shown() { date +%s%N >"$SHOWN_FILE" 2>/dev/null || true; }

# Počká, až awww dokreslí přechodovou animaci, jinak by mpvpaper naskočil doprostřed
# a přechod by se zahodil. Klient awww se vrací hned (~120 ms), animaci dělá daemon
# asynchronně (~3 s při step=10 fps=120), takže se řídíme podle jeho CPU aktivity.
#
# Spolehlivé je to proto, že u video tapety je CURRENT_WALL statický PNG snímek —
# daemon tedy po dokončení přechodu zaručeně ztichne. (U animovaného gifu/webp by
# ztichl až nikdy, ale tam se mpvpaper nepoužívá.)
wait_for_transition() {
    local pid deadline prev cur
    if [[ -n "${WALL_VIDEO_START_DELAY:-}" ]]; then
        sleep "$WALL_VIDEO_START_DELAY"
        return 0
    fi
    pid="$(pgrep -x awww-daemon 2>/dev/null | head -1 || true)"
    [[ -n "$pid" ]] || { sleep 0.5; return 0; }

    prev="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo 0)"
    deadline=$((SECONDS + ${WALL_VIDEO_START_TIMEOUT:-6}))
    while ((SECONDS < deadline)); do
        sleep 0.25
        cur="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo "$prev")"
        [[ "$cur" == "$prev" ]] && return 0
        prev="$cur"
    done
}

stop_video() {
    pgrep -x mpvpaper >/dev/null 2>&1 || return 0
    pkill -x mpvpaper >/dev/null 2>&1 || true
    # mpvpaper na SIGTERM spolehlivě nereaguje (drží si ho libmpv), takže po
    # krátkém čekání eskalujeme na SIGKILL. Bez toho by video zůstalo viset
    # nad nově nastavenou statickou tapetou. Jemné kolo po 50 ms: dřív se
    # čekalo po 0,25 s až 1,5 s a o tolik se zdržel i mark_shown.
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 0.05
        pgrep -x mpvpaper >/dev/null 2>&1 || return 0
    done
    pkill -KILL -x mpvpaper >/dev/null 2>&1 || true
    sleep 0.2
}

start_video() {
    local video="$1"
    have_mpvpaper || { mark_shown; return 0; }
    [[ -f "$video" ]] || { mark_shown; return 0; }
    [[ -f "$VIDEO_INHIBIT" ]] && { stop_video; mark_shown; return 0; }

    stop_video
    # První snímek nového videa už awww ukazuje, starý mpvpaper je pryč.
    mark_shown
    # Krátká pauza, ať se stará layer-shell surface stihne odregistrovat.
    sleep 0.2
    wait_for_transition

    # Během čekání na přechod (~3 s) mohl uživatel přepnout na jinou tapetu.
    # Tenhle běh je odpojený na pozadí, takže by jinak nastartoval staré video
    # přes novou tapetu — u přepnutí na obrázek by mpvpaper zůstal viset.
    local still=""
    [[ -f "$CURRENT_VIDEO" ]] && still="$(cat "$CURRENT_VIDEO" 2>/dev/null || true)"
    if [[ "$still" != "$video" ]]; then
        stop_video
        return 0
    fi

    # '*' = všechny výstupy; mpvpaper si sám vytvoří instanci pro každý monitor.
    # -f forkuje na pozadí, -p pauzuje přehrávání když je jiné okno fullscreen
    # (šetří baterku na notebooku).
    mpvpaper -f -p -l "$LAYER" -o "$MPV_OPTS" '*' "$video" >/dev/null 2>&1 || true
}

# Srovná stav mpvpaperu s tím, co je zapsané v current-video.
sync_video() {
    [[ -f "$VIDEO_INHIBIT" ]] && { stop_video; mark_shown; return 0; }
    if [[ -f "$CURRENT_VIDEO" ]]; then
        local video
        video="$(cat "$CURRENT_VIDEO" 2>/dev/null || true)"
        if [[ -n "$video" && -f "$video" ]]; then
            start_video "$video"
            return 0
        fi
        # Video zmizelo z disku — uklidíme stav, ať nezůstane viset.
        rm -f "$CURRENT_VIDEO"
    fi
    stop_video
    mark_shown
}

# Nastartuje mpvpaper jen pokud už neběží (pro healthcheck — nechceme
# restartovat běžící video každou minutu).
ensure_video() {
    [[ -f "$VIDEO_INHIBIT" ]] && { stop_video; return 0; }
    [[ -f "$CURRENT_VIDEO" ]] || { stop_video; return 0; }
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        return 0
    fi
    sync_video
}

# Potlačí video vrstvu, dokud ji někdo neuvolní. Používá rp-power při přepnutí
# do gaming (video dekóduje a překresluje ta samá iGPU, která zároveň přebírá
# každý snímek hry z dGPU, takže si lezou do cesty) a battery (dekód videa
# stojí citelně víc energie než statický obrázek).
inhibit_video() {
    mkdir -p "$STATE_DIR"
    : > "$VIDEO_INHIBIT"
    stop_video
}

uninhibit_video() {
    rm -f "$VIDEO_INHIBIT"
    sync_video
}

case "${1:-sync}" in
    sync)      sync_video ;;
    ensure)    ensure_video ;;
    start)     [[ -n "${2:-}" ]] && start_video "$2" ;;
    stop)      stop_video ;;
    inhibit)   inhibit_video ;;
    uninhibit) uninhibit_video ;;
    *)
        echo "Použití: $(basename "$0") {sync|ensure|start <video>|stop|inhibit|uninhibit}" >&2
        exit 1
        ;;
esac
