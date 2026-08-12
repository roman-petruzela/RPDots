#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
PID_DIR="$STATE_DIR/pids"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri-rice"
WALL_DIR="$HOME/.local/share/wallpapers"
CURRENT_WALL="$WALL_DIR/current"
CURRENT_SOURCE_FILE="$STATE_DIR/current-wallpaper-source"
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
    65-vscode.sh | 66-browser.sh | 67-fastfetch-logo-recolor.sh | 70-vesktop.sh | 80-spicetify.sh | 87-fastfetch.sh)
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
    
    if [[ -x "$HOME/.local/bin/theme-modules/01-wallpaper-transition.sh" ]]; then
        export CURRENT_WALL="$wall"
        "$HOME/.local/bin/theme-modules/01-wallpaper-transition.sh" >/dev/null 2>&1 || true
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
    stat -c '%n|%Y|%s' "$f" 2>/dev/null || printf '%s\n' "$f"
}

if [[ -n "$WALLPAPER_ARG" ]]; then
    WALLPAPER="$WALLPAPER_ARG"
    [[ -f "$WALLPAPER" ]] || {
        echo "Wallpaper not found: $WALLPAPER" >&2
        exit 1
    }
    sig="$(wallpaper_sig "$WALLPAPER")"
    last_sig_file="$STATE_DIR/last-wallpaper.sig"
    if [[ -f "$last_sig_file" ]] && [[ "$(cat "$last_sig_file" 2>/dev/null || true)" == "$sig" ]]; then
        SAME_WALLPAPER=1
        apply_wallpaper_now "$WALLPAPER"
        if [[ "${THEME_SKIP_REGEN_IF_SAME_WALLPAPER:-0}" == "1" ]]; then
            notify_msg "Rice" "Wallpaper beze zmeny — preskakuju regen theme."
            exit 0
        fi
        notify_msg "Rice" "Wallpaper beze zmeny — obnovuju theme."
    fi
    if [[ "$(readlink -f "$WALLPAPER" 2>/dev/null || printf '%s' "$WALLPAPER")" != "$(readlink -f "$CURRENT_WALL" 2>/dev/null || printf '%s' "$CURRENT_WALL")" ]]; then
        cp -f "$WALLPAPER" "$CURRENT_WALL"
    fi
    printf '%s\n' "$WALLPAPER" >"$CURRENT_SOURCE_FILE"
else
    if [[ -f "$CURRENT_WALL" ]]; then
        WALLPAPER="$CURRENT_WALL"
    else
        WALLPAPER="$(find "$HOME/Pictures" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null || true)"
        [[ -n "$WALLPAPER" ]] || exit 0
        if [[ "$(readlink -f "$WALLPAPER" 2>/dev/null || printf '%s' "$WALLPAPER")" != "$(readlink -f "$CURRENT_WALL" 2>/dev/null || printf '%s' "$CURRENT_WALL")" ]]; then
            cp -f "$WALLPAPER" "$CURRENT_WALL"
        fi
    fi
    sig="$(wallpaper_sig "$WALLPAPER")"
    last_sig_file="$STATE_DIR/last-wallpaper.sig"
    if [[ -f "$last_sig_file" ]] && [[ "$(cat "$last_sig_file" 2>/dev/null || true)" == "$sig" ]]; then
        exit 0
    fi
fi

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

wal_input="$wal_source"
if command -v magick >/dev/null 2>&1; then
    matugen_png="$STATE_DIR/wal-matugen.png"
    if [[ "$FAST_MODE" == "yes" ]]; then
        magick "${wal_source}[0]" -auto-orient -resize "960x960>" "$matugen_png" >/dev/null 2>&1 || true
    else
        magick "${wal_source}[0]" -auto-orient -resize "1920x1920>" "$matugen_png" >/dev/null 2>&1 || true
    fi
    [[ -f "$matugen_png" ]] && wal_input="$matugen_png"
fi

if command -v matugen >/dev/null 2>&1 && [[ -f "$wal_input" ]]; then
    matugen image "$wal_input" --source-color-index 0 2>/dev/null || true
fi
_matugen_json=""
if command -v matugen >/dev/null 2>&1; then
    _matugen_json="$(matugen image "$wal_input" --source-color-index 0 -j hex 2>/dev/null || true)"
fi

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
    m = re.match(r'^\s*(\d+):.*#([0-9A-Fa-f]{6})\b', line)
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
        accent="$(echo "$image_pick" | sed -n '1p')"
        second="$(echo "$image_pick" | sed -n '2p')"
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
