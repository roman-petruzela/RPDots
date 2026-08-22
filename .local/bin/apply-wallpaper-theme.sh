#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
PID_DIR="$STATE_DIR/pids"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri-rice"
WALL_DIR="$HOME/.local/share/wallpapers"
CURRENT_WALL="$WALL_DIR/current"
CURRENT_SOURCE_FILE="$STATE_DIR/current-wallpaper-source"
# Drží cestu k video tapetě, pokud je aktivní. Neexistuje = statická tapeta.
CURRENT_VIDEO_FILE="$STATE_DIR/current-video"
MODULE_DIR="$HOME/.local/bin/theme-modules"
THEME_LOG="$STATE_DIR/theme-modules.log"
MODULE_CFG="$CFG_DIR/modules.conf"
SNAPSHOT_ROOT="$STATE_DIR/snapshots"
WAYBAR_RESTART_ON_THEME="${WAYBAR_RESTART_ON_THEME:-0}"
WAYBAR_CSS="$HOME/.config/waybar/colors.css"
WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
LOCK_DIR="$STATE_DIR/theme-apply.lock.d"
PENDING_FLAG="$STATE_DIR/theme-apply.pending"
PENDING_ARGS="$STATE_DIR/theme-apply.pending.args"
NO_RESTART=""
FAST_MODE=""
SNAPSHOT_DIR=""
MANIFEST_FILE=""
RESTORE_DONE=0
WALLPAPER_ARG=""
SAME_WALLPAPER=0
waybar_css_hash_before=""
waybar_config_hash_before=""
waybar_css_changed=0
waybar_config_changed=0

mkdir -p "$STATE_DIR"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s\0' "$@" >"$PENDING_ARGS"
    : >"$PENDING_FLAG"
    exit 0
fi

cleanup_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup_lock EXIT

mkdir -p "$PID_DIR" "$WALL_DIR" "$CFG_DIR" "$SNAPSHOT_ROOT"
export PATH="$HOME/.local/bin:$HOME/.spicetify:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
if [[ -f "$WAYBAR_CSS" ]]; then
    waybar_css_hash_before="$(sha256sum "$WAYBAR_CSS" | awk '{print $1}')"
fi
if [[ -f "$WAYBAR_CONFIG" ]]; then
    waybar_config_hash_before="$(sha256sum "$WAYBAR_CONFIG" | awk '{print $1}')"
fi

notify_msg() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "rice" "$1" "$2"
    fi
}

parse_meta() {
    local module="$1"
    local base enabled priority requires
    base="$(basename "$module")"
    enabled=""
    priority=""
    requires=""
    # Parse module metadata in one pass (fewer forks than multiple greps).
    IFS='|' read -r enabled priority requires < <(
        awk -F': *' '
      BEGIN { e=""; p=""; r="" }
      /^# enabled:/  && e=="" { e=$2 }
      /^# priority:/ && p=="" { p=$2 }
      /^# requires:/ && r=="" { r=$2 }
      { if (NR >= 80) exit }
      END { gsub(/^[ \t]+|[ \t]+$/, "", e); gsub(/^[ \t]+|[ \t]+$/, "", p); gsub(/^[ \t]+|[ \t]+$/, "", r); print e "|" p "|" r }
    ' "$module"
    )
    printf '%s|%s|%s|%s\n' "$base" "$enabled" "$priority" "$requires"
}

ensure_modules_cfg() {
    if [[ -f "$MODULE_CFG" ]]; then
        return
    fi
    cat >"$MODULE_CFG" <<'EOF'
# module|enabled|priority|requires(comma separated commands)
05-cache-hygiene.sh|1|5|
10-kitty.sh|1|10|kitty
15-zed.sh|1|15|
16-cli-theme-env.sh|1|16|
20-waybar.sh|1|20|
30-niri.sh|1|30|
40-mako.sh|1|40|
50-fuzzel.sh|1|50|
55-rofi.sh|1|55|
60-gtk.sh|1|60|
61-thunar.sh|1|61|
62-qt.sh|1|62|qt5ct,qt6ct
63-dcol.sh|1|63|
65-vscode.sh|1|65|jq
66-browser.sh|1|66|jq
70-vesktop.sh|1|70|jq
80-spicetify.sh|1|80|spicetify
85-cava.sh|1|85|
86-btop.sh|1|86|
87-fastfetch.sh|1|87|
88-alacritty.sh|1|88|
89-swaylock.sh|1|89|
90-eww.sh|1|90|
95-smoke-test.sh|1|95|
EOF
}

load_module_cfg() {
    declare -gA CFG_ENABLED CFG_PRIORITY CFG_REQUIRES
    while IFS='|' read -r module enabled priority requires; do
        [[ -z "${module:-}" || "${module:0:1}" == "#" ]] && continue
        CFG_ENABLED["$module"]="${enabled:-1}"
        CFG_PRIORITY["$module"]="${priority:-}"
        CFG_REQUIRES["$module"]="${requires:-}"
    done <"$MODULE_CFG"
}

collect_tracked_files() {
    cat <<EOF
$HOME/.config/kitty/current-theme.conf
$HOME/.config/waybar/colors.css
$HOME/.config/niri/theme-colors.kdl
$HOME/.config/mako/config
$HOME/.config/fuzzel/fuzzel.ini
$HOME/.config/rofi/pywal-dynamic.rasi
$HOME/.config/yazi/theme.toml
$HOME/.config/gtk-3.0/gtk.css
$HOME/.config/gtk-4.0/gtk.css
$HOME/.config/gtk-3.0/settings.ini
$HOME/.config/gtk-4.0/settings.ini
$HOME/.config/vesktop/settings/quickCss.css
$HOME/.config/vesktop/settings/settings.json
$HOME/.config/spicetify/Themes/PywalDynamic/color.ini
$HOME/.config/spicetify/Themes/PywalDynamic/user.css
$HOME/.config/Code/User/settings.json
$HOME/.config/fastfetch/config.jsonc
$HOME/.config/qt5ct/colors/NiriRiceWal.conf
$HOME/.config/qt6ct/colors/NiriRiceWal.conf
$HOME/.config/Kvantum/niri-rice/niri-rice.kvconfig
$HOME/.config/chromium-flags.conf
$HOME/.config/google-chrome-flags.conf
$HOME/.config/brave-flags.conf
EOF
    find "$HOME/.mozilla/firefox" -maxdepth 3 -type f \( -name user.js -o -name userChrome.css -o -name userContent.css \) 2>/dev/null || true
}

snapshot_files() {
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    SNAPSHOT_DIR="$SNAPSHOT_ROOT/$ts"
    MANIFEST_FILE="$SNAPSHOT_DIR/manifest"
    mkdir -p "$SNAPSHOT_DIR"
    : >"$MANIFEST_FILE"
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        if [[ -f "$file" ]]; then
            printf 'exists|%s\n' "$file" >>"$MANIFEST_FILE"
            mkdir -p "$SNAPSHOT_DIR$(dirname "$file")"
            cp -a "$file" "$SNAPSHOT_DIR$file"
        else
            printf 'absent|%s\n' "$file" >>"$MANIFEST_FILE"
        fi
    done < <(collect_tracked_files | awk '!seen[$0]++')
}

restore_files() {
    [[ -f "$MANIFEST_FILE" ]] || return 0
    while IFS='|' read -r state file; do
        [[ -n "$file" ]] || continue
        if [[ "$state" == "exists" ]]; then
            mkdir -p "$(dirname "$file")"
            cp -a "$SNAPSHOT_DIR$file" "$file"
        else
            rm -f "$file"
        fi
    done <"$MANIFEST_FILE"
}

cleanup_snapshots() {
    find "$SNAPSHOT_ROOT" -mindepth 1 -maxdepth 1 -type d | sort | head -n -5 2>/dev/null | while IFS= read -r old; do
        rm -rf "$old"
    done
}

on_err() {
    local rc="$1"
    if [[ "$RESTORE_DONE" -eq 0 ]]; then
        restore_files
        RESTORE_DONE=1
    fi
    notify_msg "Rice" "Theme selhalo. Rollback hotov. Kod: $rc"
    exit "$rc"
}

trap 'on_err $?' ERR

is_heavy_module() {
    case "$1" in
    65-vscode.sh | 66-browser.sh | 70-vesktop.sh | 80-spicetify.sh | 87-fastfetch.sh)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

apply_wallpaper_now() {
    local wall="$1"
    local daemon=""
    
    if command -v awww-daemon >/dev/null 2>&1 && command -v awww >/dev/null 2>&1; then
        daemon="awww-daemon"
    elif command -v swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
        daemon="swww-daemon"
    else
        return 0
    fi
    
    if ! pgrep -x "$daemon" >/dev/null 2>&1; then
        "$daemon" >/dev/null 2>&1 &
        sleep 0.3
    fi
    
    # Run wallpaper transition module
    if [[ -x "$HOME/.local/bin/theme-modules/01-wallpaper-transition.sh" ]]; then
        export CURRENT_WALL="$wall"
        "$HOME/.local/bin/theme-modules/01-wallpaper-transition.sh" >/dev/null 2>&1 || true
    fi
}

is_video_wallpaper() {
    case "${1,,}" in
        *.mp4 | *.mkv | *.webm | *.mov | *.avi) return 0 ;;
        *) return 1 ;;
    esac
}

# Připraví $CURRENT_WALL a stav videa.
#
# CURRENT_WALL je *vždy* obrázek, i když je vybrané video — v tom případě do něj
# uložíme první snímek. Matugen z něj vytáhne barvy, awww ho zobrazí jako podklad
# a přechodový efekt tak vypadá stejně jako u obrázkových tapet. Teprve navrch
# se pak položí mpvpaper s videem.
install_wallpaper_source() {
    local src="$1"

    if is_video_wallpaper "$src"; then
        if ! command -v ffmpeg >/dev/null 2>&1; then
            echo "ffmpeg chybí, video tapetu nelze použít: $src" >&2
            return 1
        fi
        local frame="$STATE_DIR/video-frame.png"
        # Filtr thumbnail vybere z prvních 100 snímků ten nejreprezentativnější.
        # Prostý -frames:v 1 by u videí s fade-in z černé vytáhl černý snímek —
        # a matugen by z něj udělal generickou tmavou paletu, takže by to
        # vypadalo, že video tapety barvy vůbec nemění.
        if ! ffmpeg -y -v error -i "$src" -vf "thumbnail=100" -frames:v 1 -f image2 "$frame" >/dev/null 2>&1; then
            # Záloha pro velmi krátká videa, kde thumbnail nemá z čeho vybírat.
            if ! ffmpeg -y -v error -i "$src" -frames:v 1 -f image2 "$frame" >/dev/null 2>&1; then
                echo "Nepodařilo se vytáhnout snímek z videa: $src" >&2
                return 1
            fi
        fi
        cp -f "$frame" "$CURRENT_WALL"
        printf '%s\n' "$src" >"$CURRENT_VIDEO_FILE"
        return 0
    fi

    rm -f "$CURRENT_VIDEO_FILE"
    if [[ "$(readlink -f "$src" 2>/dev/null || printf '%s' "$src")" != "$(readlink -f "$CURRENT_WALL" 2>/dev/null || printf '%s' "$CURRENT_WALL")" ]]; then
        cp -f "$src" "$CURRENT_WALL"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --no-daemon-restart)
        NO_RESTART="yes"
        shift
        ;;
    --fast)
        FAST_MODE="yes"
        shift
        ;;
    --*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    *)
        WALLPAPER_ARG="$1"
        shift
        ;;
    esac
done

wallpaper_sig() {
    local f="$1"
    # Fast signature: path + mtime + size (good enough to detect changes cheaply).
    stat -c '%n|%Y|%s' "$f" 2>/dev/null || printf '%s\n' "$f"
}

if [[ -n "$WALLPAPER_ARG" ]]; then
    WALLPAPER="$WALLPAPER_ARG"
    [[ -f "$WALLPAPER" ]] || {
        echo "Wallpaper not found: $WALLPAPER" >&2
        exit 1
    }
    # Musí proběhnout před prvním přechodem — awww i matugen pracují s CURRENT_WALL,
    # a u videa ho teprve tohle naplní prvním snímkem.
    install_wallpaper_source "$WALLPAPER" || exit 1
    printf '%s\n' "$WALLPAPER" >"$CURRENT_SOURCE_FILE"
    sig="$(wallpaper_sig "$WALLPAPER")"
    last_sig_file="$STATE_DIR/last-wallpaper.sig"
    if [[ -f "$last_sig_file" ]] && [[ "$(cat "$last_sig_file" 2>/dev/null || true)" == "$sig" ]]; then
        SAME_WALLPAPER=1
        apply_wallpaper_now "$CURRENT_WALL"
        if [[ "${THEME_SKIP_REGEN_IF_SAME_WALLPAPER:-0}" == "1" ]]; then
            notify_msg "Rice" "Wallpaper beze zmeny — preskakuju regen theme."
            exit 0
        fi
        notify_msg "Rice" "Wallpaper beze zmeny — obnovuju theme."
    fi
else
    if [[ -f "$CURRENT_WALL" ]]; then
        WALLPAPER="$CURRENT_WALL"
    else
        # Stop as soon as we find the first matching file (much faster than piping to head).
        WALLPAPER="$(find "$HOME/Pictures" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null || true)"
        [[ -n "$WALLPAPER" ]] || exit 0
        if [[ "$(readlink -f "$WALLPAPER" 2>/dev/null || printf '%s' "$WALLPAPER")" != "$(readlink -f "$CURRENT_WALL" 2>/dev/null || printf '%s' "$CURRENT_WALL")" ]]; then
            cp -f "$WALLPAPER" "$CURRENT_WALL"
        fi
    fi
    # Triggered by systemd path unit without a new wallpaper: skip if nothing actually changed.
    sig="$(wallpaper_sig "$WALLPAPER")"
    last_sig_file="$STATE_DIR/last-wallpaper.sig"
    if [[ -f "$last_sig_file" ]] && [[ "$(cat "$last_sig_file" 2>/dev/null || true)" == "$sig" ]]; then
        # At fresh login the wallpaper daemon isn't running yet — restore wallpaper without re-running matugen.
        _wd="swww-daemon"; command -v awww-daemon >/dev/null 2>&1 && _wd="awww-daemon"
        if ! pgrep -x "$_wd" >/dev/null 2>&1; then
            apply_wallpaper_now "$WALLPAPER"
        fi
        exit 0
    fi
fi

# Start wallpaper transition immediately so it's visible at once.
# Theme processing (matugen, modules) runs after — the transition daemon is
# GPU-side so CPU work doesn't stutter the animation.
apply_wallpaper_now "$CURRENT_WALL"
export WALLPAPER_TRANSITION_DONE=1
printf '%s\n' "$(wallpaper_sig "$WALLPAPER")" >"$STATE_DIR/last-wallpaper.sig" 2>/dev/null || true

wal_source="$WALLPAPER"
if [[ -f "$CURRENT_SOURCE_FILE" ]]; then
    source_wall="$(cat "$CURRENT_SOURCE_FILE" 2>/dev/null || true)"
    if [[ -n "$source_wall" && -f "$source_wall" ]]; then
        wal_source="$source_wall"
    fi
fi

# U videa bereme barvy z už vytaženého prvního snímku v CURRENT_WALL, ne ze
# samotného .mp4 — magick by ho musel dekódovat znovu (u 4K souboru zbytečně)
# a spoléhal by přitom na ffmpeg delegáta, který nemusí být všude k dispozici.
if is_video_wallpaper "$wal_source" && [[ -f "$CURRENT_WALL" ]]; then
    wal_source="$CURRENT_WALL"
fi

wal_input="$wal_source"
if command -v magick >/dev/null 2>&1; then
    # matugen cannot read JPEG — always convert to PNG for color extraction.
    # Resize to 1920px max; beyond that resolution adds no color accuracy.
    matugen_png="$STATE_DIR/wal-matugen.png"
    # Smazat předem: kdyby magick selhal, zůstal by tu snímek z předchozí tapety
    # a matugen by tiše vygeneroval staré barvy (vypadá to jako "barvy se nemění").
    rm -f "$matugen_png"
    if [[ "$FAST_MODE" == "yes" ]]; then
        magick "${wal_source}[0]" -auto-orient -resize "960x960>" "$matugen_png" >/dev/null 2>&1 || true
    else
        magick "${wal_source}[0]" -auto-orient -resize "1920x1920>" "$matugen_png" >/dev/null 2>&1 || true
    fi
    [[ -f "$matugen_png" ]] && wal_input="$matugen_png"
fi

# Black-and-white wallpapers have no hue to derive anything from, and matugen's
# quantizer then seeds the scheme from a near-black pixel whose channels differ by
# a unit or two of compression noise. saturn-monochrome.mp4 seeds #040206 — that is
# hue 270 at 2.4 % value, and Material You blows it up into a full purple palette.
# Detect the case and ask for scheme-monochrome instead of guessing a hue.
is_mono_wallpaper() {
    local img="$1"
    command -v python3 >/dev/null 2>&1 || return 1
    command -v magick >/dev/null 2>&1 || return 1
    [[ -f "$img" ]] || return 1
    THEME_MONO_THRESHOLD="${THEME_MONO_THRESHOLD:-2.0}" python3 - "$img" <<'PY'
import colorsys, os, re, subprocess, sys

proc = subprocess.run(
    ["magick", f"{sys.argv[1]}[0]", "-auto-orient", "-resize", "320x320>",
     "-colors", "64", "-format", "%c\n", "histogram:info:-"],
    capture_output=True, text=True,
)
if proc.returncode != 0:
    sys.exit(1)

total = colored = 0
for line in proc.stdout.splitlines():
    m = re.match(r'^\s*(\d+):.*#([0-9A-Fa-f]{6})(?:[0-9A-Fa-f]{2})?\b', line)
    if not m:
        continue
    count = int(m.group(1))
    hexv = m.group(2)
    r, g, b = (int(hexv[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    _, s, v = colorsys.rgb_to_hsv(r, g, b)
    total += count
    # Near-black and near-white pixels carry no usable hue, so they count towards
    # the total but never towards "this image has colour".
    if s >= 0.15 and v >= 0.12:
        colored += count

if not total:
    sys.exit(1)
pct = colored / total * 100.0
sys.exit(0 if pct < float(os.environ["THEME_MONO_THRESHOLD"]) else 1)
PY
}

# Measured over the wallpaper collection, the two groups sit far apart: the
# monochrome ones land at 0.00 %, the darkest still-colourful one (void-space-
# black-hole) at 5.19 %, everything else well above. 2 % separates them cleanly.
MONO_MODE="${THEME_MONO_MODE:-auto}"
MATUGEN_ARGS=()
case "$MONO_MODE" in
on) IS_MONO=1 ;;
off) IS_MONO=0 ;;
*) if is_mono_wallpaper "$wal_input"; then IS_MONO=1; else IS_MONO=0; fi ;;
esac

if [[ "$IS_MONO" == "1" ]]; then
    MATUGEN_ARGS+=(-t scheme-monochrome)
    # scheme-monochrome hands back true greys, but the templates pin saturation
    # (`set_saturation: 30`) to keep surfaces coloured — on a grey that resolves to
    # hue 0 and repaints everything red-brown (#d4d4d4 -> #3c2020). matugen has no
    # conditionals, so generate a grey variant of those templates and point a copy
    # of the config at it. The templates stay the single source of truth.
    mono_cfg="$(MONO_DIR="$STATE_DIR/templates-mono" python3 - <<'PY' 2>/dev/null || true
import os, pathlib, re, sys

cfg = pathlib.Path(os.path.expanduser("~/.config/matugen/config.toml"))
if not cfg.is_file():
    sys.exit(1)
mono_dir = pathlib.Path(os.environ["MONO_DIR"])
mono_dir.mkdir(parents=True, exist_ok=True)

out = []
for line in cfg.read_text().splitlines():
    m = re.match(r'^(\s*input_path\s*=\s*")(.+)(")\s*$', line)
    if m:
        src = pathlib.Path(os.path.expanduser(m.group(2)))
        if src.is_file():
            text = src.read_text()
            if "set_saturation" in text:
                dst = mono_dir / src.name
                dst.write_text(re.sub(r'set_saturation:\s*\d+(\.\d+)?', 'set_saturation: 0', text))
                line = f"{m.group(1)}{dst}{m.group(3)}"
    out.append(line)

dst_cfg = mono_dir / "config.toml"
dst_cfg.write_text("\n".join(out) + "\n")
print(dst_cfg)
PY
)"
    if [[ -n "$mono_cfg" && -f "$mono_cfg" ]]; then
        MATUGEN_ARGS+=(-c "$mono_cfg")
    fi
fi

# Generate color scheme with matugen: templates first (Colors.js, waybar, kitty, gtk…),
# then extract JSON for the bash color variables used by the remaining modules.
if command -v matugen >/dev/null 2>&1 && [[ -f "$wal_input" ]]; then
    matugen "${MATUGEN_ARGS[@]}" image "$wal_input" --source-color-index 0 2>/dev/null || true
fi
_matugen_json=""
if command -v matugen >/dev/null 2>&1; then
    _matugen_json="$(matugen "${MATUGEN_ARGS[@]}" image "$wal_input" --source-color-index 0 -j hex 2>/dev/null || true)"
fi

# Extract matugen colors into pywal-compatible shell variables
# NOTE: pipe+heredoc for python3 is broken (pipe overrides heredoc as script src);
# pass JSON via env var instead.
export _MATUGEN_JSON="$_matugen_json"
eval "$(python3 - <<'PYEOF'
import json, os
txt = os.environ.get("_MATUGEN_JSON", "").strip()
fallbacks = {
    "background": "#1a120d", "on_surface": "#f0dfd7", "primary": "#ffb68c",
    "surface_container_lowest": "#140d08", "error": "#ffb4ab",
    "tertiary": "#ccc992", "secondary": "#e5bfaa",
    "tertiary_fixed_dim": "#ccc992", "secondary_fixed_dim": "#e5bfaa",
    "on_surface_variant": "#d7c2b8", "surface_container": "#271e19",
    "error_container": "#93000a", "tertiary_container": "#4a481d",
    "secondary_container": "#5c4131", "primary_container": "#6f3812",
    "tertiary_fixed": "#e9e5ab", "secondary_fixed": "#ffdbc9",
}
c = fallbacks.copy()
try:
    data = json.loads(txt[txt.index("{"):])
    for k, v in data.get("colors", {}).items():
        c[k] = v.get("default", {}).get("color", fallbacks.get(k, "#000000"))
except Exception:
    pass
print(f'background="{c["background"]}"')
print(f'foreground="{c["on_surface"]}"')
print(f'cursor="{c["primary"]}"')
print(f'color0="{c["surface_container_lowest"]}"')
print(f'color1="{c["error"]}"')
print(f'color2="{c["tertiary"]}"')
print(f'color3="{c["secondary"]}"')
print(f'color4="{c["primary"]}"')
print(f'color5="{c["tertiary_fixed_dim"]}"')
print(f'color6="{c["secondary_fixed_dim"]}"')
print(f'color7="{c["on_surface_variant"]}"')
print(f'color8="{c["surface_container"]}"')
print(f'color9="{c["error_container"]}"')
print(f'color10="{c["tertiary_container"]}"')
print(f'color11="{c["secondary_container"]}"')
print(f'color12="{c["primary_container"]}"')
print(f'color13="{c["tertiary_fixed"]}"')
print(f'color14="{c["secondary_fixed"]}"')
print(f'color15="{c["on_surface"]}"')
PYEOF
)"
unset _MATUGEN_JSON

pick_vivid_color() {
    command -v python3 >/dev/null 2>&1 || return 1
    python3 - "$@" <<'PY'
import colorsys, sys
cands = sys.argv[1:]
scored = []
for c in cands:
    if not c or not c.startswith("#") or len(c) != 7:
        continue
    r = int(c[1:3], 16) / 255.0
    g = int(c[3:5], 16) / 255.0
    b = int(c[5:7], 16) / 255.0
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    score = (s * 0.82) + (v * 0.18)
    scored.append((score, c))
scored.sort(reverse=True)
if scored:
    print(scored[0][1])
    if len(scored) > 1:
        print(scored[1][1])
PY
}

pick_image_accent() {
    local image="$1"
    command -v python3 >/dev/null 2>&1 || return 1
    command -v magick >/dev/null 2>&1 || return 1
    [[ -f "$image" ]] || return 1
    python3 - "$image" <<'PY'
import colorsys, re, subprocess, sys

image = sys.argv[1]
proc = subprocess.run(
    ["magick", f"{image}[0]", "-auto-orient", "-resize", "320x320>", "-colors", "16", "-format", "%c\n", "histogram:info:-"],
    capture_output=True,
    text=True,
)
if proc.returncode != 0:
    sys.exit(1)

rows = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
cands = []
for line in rows:
    # Wallpapers with an alpha channel make ImageMagick print #RRGGBBAA, so the
    # trailing pair has to be optional — with a fixed six the \b never matched,
    # every candidate was dropped and accent came out empty.
    m = re.match(r'^\s*(\d+):.*#([0-9A-Fa-f]{6})(?:[0-9A-Fa-f]{2})?\b', line)
    if not m:
        continue
    count = int(m.group(1))
    hexv = m.group(2).upper()
    r = int(hexv[0:2], 16) / 255.0
    g = int(hexv[2:4], 16) / 255.0
    b = int(hexv[4:6], 16) / 255.0
    _, s, v = colorsys.rgb_to_hsv(r, g, b)
    if v < 0.20:
        continue
    score = count * (0.25 + (s * 0.75)) * (0.35 + (v * 0.65))
    cands.append((score, f"#{hexv}", s))

cands.sort(reverse=True)
if cands:
    print(cands[0][1])
    second = None
    for _, hexv, sat in cands[1:]:
        if sat >= 0.18:
            second = hexv
            break
    if second:
        print(second)
PY
}

accent="${color5}"
accent_soft="${color6}"
accent_blue="${color4}"
accent_urgent="${color1}"

accent_mode="${THEME_ACCENT_MODE:-image}"
case "$accent_mode" in
image)
    if image_pick="$(pick_image_accent "$WALLPAPER")"; then
        first="$(echo "$image_pick" | sed -n '1p')"
        second="$(echo "$image_pick" | sed -n '2p')"
        # The picker can legitimately come up empty (an all-dark wallpaper drops
        # every candidate). Keep the matugen fallback then — an empty accent is
        # written straight into theme-colors.kdl and makes the niri config invalid.
        if [[ -n "${first:-}" ]]; then
            accent="$first"
        fi
        if [[ -n "${second:-}" ]]; then
            accent_blue="$second"
        fi
    fi
    ;;
vivid)
    if vivid="$(pick_vivid_color "${color1}" "${color2}" "${color3}" "${color4}" "${color5}" "${color6}")"; then
        accent="$(echo "$vivid" | sed -n '1p')"
        second="$(echo "$vivid" | sed -n '2p')"
        if [[ -n "${second:-}" ]]; then
            accent_blue="$second"
        fi
    fi
    ;;
wal | *)
    ;;
esac

# Last-resort net: whatever happened above, no accent may reach the modules empty.
# 30-niri.sh interpolates these straight into KDL, and `active-color ""` fails
# `niri validate`, so the whole config (not just the colors) stops loading.
: "${accent:=${color5:-#ffb68c}}"
: "${accent_soft:=${color6:-#e5bfaa}}"
: "${accent_blue:=${color4:-#ffb68c}}"
: "${accent_urgent:=${color1:-#ffb4ab}}"
[[ -n "$accent" ]] || accent="#ffb68c"
[[ -n "$accent_soft" ]] || accent_soft="#e5bfaa"
[[ -n "$accent_blue" ]] || accent_blue="#ffb68c"
[[ -n "$accent_urgent" ]] || accent_urgent="#ffb4ab"

if [[ "${THEME_ACCENT_SOFT_FOLLOW_ACCENT:-0}" == "1" ]]; then
    accent_soft="$accent"
fi
if [[ "${THEME_ACCENT_BLUE_FOLLOW_ACCENT:-0}" == "1" ]]; then
    accent_blue="$accent"
fi

export HOME PID_DIR NO_RESTART CURRENT_WALL WALLPAPER
export background foreground cursor
export color0 color1 color2 color3 color4 color5 color6 color7 color8 color9 color10 color11 color12 color13 color14 color15
export accent accent_soft accent_blue accent_urgent

if [[ "$FAST_MODE" != "yes" ]]; then
    snapshot_files
fi
ensure_modules_cfg
load_module_cfg

if [[ -d "$MODULE_DIR" ]]; then
    : >"$THEME_LOG"
    failed_modules=()
    runlist="$(mktemp)"
    while IFS= read -r module; do
        [[ -x "$module" ]] || continue
        IFS='|' read -r base meta_enabled meta_priority meta_requires < <(parse_meta "$module")

        enabled="${CFG_ENABLED[$base]:-${meta_enabled:-1}}"
        if [[ "$enabled" != "1" ]]; then
            printf '[skip] %s disabled\n' "$base" >>"$THEME_LOG"
            continue
        fi

        if [[ "$FAST_MODE" == "yes" ]] && is_heavy_module "$base"; then
            printf '[skip] %s deferred (fast mode)\n' "$base" >>"$THEME_LOG"
            continue
        fi

        priority="${CFG_PRIORITY[$base]:-${meta_priority:-}}"
        if [[ -z "$priority" ]]; then
            if [[ "$base" =~ ^([0-9]+)- ]]; then
                priority="${BASH_REMATCH[1]}"
            else
                priority="999"
            fi
        fi

        requires="${CFG_REQUIRES[$base]:-${meta_requires:-}}"
        missing=()
        if [[ -n "$requires" ]]; then
            IFS=',' read -r -a reqs <<<"$requires"
            for req in "${reqs[@]}"; do
                req="$(echo "$req" | xargs)"
                [[ -n "$req" ]] || continue
                command -v "$req" >/dev/null 2>&1 || missing+=("$req")
            done
        fi
        if [[ ${#missing[@]} -gt 0 ]]; then
            printf '[skip] %s missing deps: %s\n' "$base" "${missing[*]}" >>"$THEME_LOG"
            continue
        fi

        printf '%s|%s\n' "$priority" "$module" >>"$runlist"
    done < <(find "$MODULE_DIR" -maxdepth 1 -type f -name '*.sh' | sort)

    async_enabled="${THEME_ASYNC:-1}"
    async_pids=()
    async_names=()
    while IFS='|' read -r _priority module; do
        [[ -x "$module" ]] || continue
        base="$(basename "$module")"
        if [[ "$async_enabled" == "1" ]] && is_heavy_module "$base"; then
            printf '[async] %s started\n' "$base" >>"$THEME_LOG"
            (
                "$module" >>"$THEME_LOG" 2>&1
                printf '[async] %s done rc=%s\n' "$base" "$?" >>"$THEME_LOG"
            ) &
            async_pids+=("$!")
            async_names+=("$base")
            continue
        fi
        if ! "$module" >>"$THEME_LOG" 2>&1; then
            failed_modules+=("$base")
        fi
    done < <(sort -t'|' -k1,1n -k2,2 "$runlist")
    rm -f "$runlist"

    if [[ ${#failed_modules[@]} -gt 0 ]]; then
        notify_msg "Rice" "Theme modul selhal: ${failed_modules[*]}"
        exit 1
    fi

    # By default we do NOT wait for async heavy modules. To wait: export THEME_ASYNC_WAIT=1
    if [[ "${THEME_ASYNC_WAIT:-0}" == "1" ]] && [[ ${#async_pids[@]} -gt 0 ]]; then
        for pid in "${async_pids[@]}"; do
            wait "$pid" || true
        done
    fi
fi
if [[ -f "$WAYBAR_CSS" ]]; then
    waybar_css_hash_after="$(sha256sum "$WAYBAR_CSS" | awk '{print $1}')"
    if [[ -n "$waybar_css_hash_after" && "$waybar_css_hash_after" != "$waybar_css_hash_before" ]]; then
        waybar_css_changed=1
    fi
fi
if [[ -f "$WAYBAR_CONFIG" ]]; then
    waybar_config_hash_after="$(sha256sum "$WAYBAR_CONFIG" | awk '{print $1}')"
    if [[ -n "$waybar_config_hash_after" && "$waybar_config_hash_after" != "$waybar_config_hash_before" ]]; then
        waybar_config_changed=1
    fi
fi

ensure_pidfile_running() {
    local pidfile="$1"
    local proc_name="$2"
    shift 2

    if [[ -f "$pidfile" ]]; then
        local pid
        pid="$(cat "$pidfile" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi

    local existing_pid
    existing_pid="$(pgrep -x "$proc_name" | head -n 1 || true)"
    if [[ -n "$existing_pid" ]]; then
        echo "$existing_pid" >"$pidfile"
        return 0
    fi

    "$@" >/dev/null 2>&1 &
    echo $! >"$pidfile"
}

signal_running_processes() {
    local proc_name="$1"
    local sig="$2"
    while IFS= read -r pid; do
        [[ -n "${pid:-}" ]] || continue
        kill "-$sig" "$pid" 2>/dev/null || true
    done < <(pgrep -x "$proc_name" 2>/dev/null || true)
}

restart_waybar_if_running() {
    [[ "$WAYBAR_RESTART_ON_THEME" == "1" ]] || return 0
    mapfile -t pids < <(pgrep -x waybar 2>/dev/null || true)
    ((${#pids[@]})) || return 0
    for pid in "${pids[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done
    for _ in {1..15}; do
        sleep 0.1
        pgrep -x waybar >/dev/null 2>&1 || break
    done
    if [[ -x "$HOME/.local/bin/waybar-watchdog.sh" ]]; then
        "$HOME/.local/bin/waybar-watchdog.sh" >/dev/null 2>&1 || true
    else
        waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
        echo $! >"$PID_DIR/waybar.pid"
    fi
}

if [[ "$NO_RESTART" != "yes" ]]; then
    ensure_pidfile_running "$PID_DIR/waybar.pid" waybar waybar
    ensure_pidfile_running "$PID_DIR/mako.pid" mako mako
fi

# Always reload running daemons so systemd-triggered theme applies (with --no-daemon-restart)
# still refresh Waybar/Mako without spawning new processes.
signal_running_processes waybar USR2
if [[ "$waybar_css_changed" -eq 1 || "$waybar_config_changed" -eq 1 ]]; then
    restart_waybar_if_running
fi
if command -v makoctl >/dev/null 2>&1; then
    makoctl reload >/dev/null 2>&1 || true
fi

niri msg action load-config-file >/dev/null 2>&1 || true
pending_args=()
if [[ -f "$PENDING_FLAG" ]]; then
    rm -f "$PENDING_FLAG"
    if [[ -s "$PENDING_ARGS" ]]; then
        mapfile -d '' -t pending_args <"$PENDING_ARGS"
    fi
    rm -f "$PENDING_ARGS"
    # If pending has no new wallpaper (just a systemd path-unit re-trigger), skip it —
    # we just finished applying, so sig will match and the else-branch would exit 0 anyway.
    has_wall_arg=0
    for a in "${pending_args[@]}"; do
        [[ -f "$a" ]] && has_wall_arg=1 && break
    done
    if [[ "$has_wall_arg" == "0" ]]; then
        cleanup_lock
        trap - EXIT
        exit 0
    fi
    cleanup_lock
    trap - EXIT
    exec "$0" "${pending_args[@]}"
fi
notify_msg "Rice" "Theme aplikovano."
if [[ "$FAST_MODE" != "yes" ]]; then
    cleanup_snapshots
fi
