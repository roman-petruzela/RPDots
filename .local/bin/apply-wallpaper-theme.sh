#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
PID_DIR="$STATE_DIR/pids"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri-rice"
WALL_DIR="$HOME/.local/share/wallpapers"
CURRENT_WALL="$WALL_DIR/current"
CURRENT_SOURCE_FILE="$STATE_DIR/current-wallpaper-source"
CURRENT_VIDEO_FILE="$STATE_DIR/current-video"
MODULE_DIR="$HOME/.local/bin/theme-modules"
THEME_LOG="$STATE_DIR/theme-modules.log"
MODULE_CFG="$CFG_DIR/modules.conf"
SNAPSHOT_ROOT="$STATE_DIR/snapshots"
LOCK_DIR="$STATE_DIR/theme-apply.lock.d"
PENDING_FLAG="$STATE_DIR/theme-apply.pending"
PENDING_ARGS="$STATE_DIR/theme-apply.pending.args"
SNAPSHOT_DIR=""
MANIFEST_FILE=""
RESTORE_DONE=0
WALLPAPER_ARG=""

mkdir -p "$STATE_DIR"
lock_is_stale() {
    local owner
    owner=$(cat "$LOCK_DIR/pid" 2>/dev/null)
    if [[ -n "$owner" ]]; then
        ! kill -0 "$owner" 2>/dev/null
    else
        [[ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +10 2>/dev/null)" ]]
    fi
}
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    if lock_is_stale; then
        rm -f "$LOCK_DIR/pid"
    else
        printf '%s\0' "$@" >"$PENDING_ARGS"
        : >"$PENDING_FLAG"
        if [[ -f "${1:-}" ]]; then
            printf '%s\n' "$1" >"$STATE_DIR/current-wallpaper-source"
            case "${1,,}" in
            *.mp4 | *.mkv | *.webm | *.mov | *.avi) printf '%s\n' "$1" >"$STATE_DIR/current-video" ;;
            *)
                rm -f "$STATE_DIR/current-video"
                awww img "$1" --transition-type "${WALL_TRANSITION_TYPE:-simple}" >/dev/null 2>&1 || true
                ;;
            esac
            setsid "$HOME/.local/bin/wallpaper-video-ctl.sh" sync >/dev/null 2>&1 </dev/null &
        fi
        exit 0
    fi
fi
echo $$ >"$LOCK_DIR/pid"

cleanup_lock() {
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup_lock EXIT

mkdir -p "$PID_DIR" "$WALL_DIR" "$CFG_DIR" "$SNAPSHOT_ROOT"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.spicetify:${PATH:-}"

notify_msg() {
    notify-send -a "rice" "$1" "$2" 2>/dev/null || true
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

load_module_cfg() {
    declare -gA CFG_ENABLED CFG_PRIORITY CFG_REQUIRES
    [[ -f "$MODULE_CFG" ]] || return 0
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
$HOME/.config/niri/theme-colors.kdl
$HOME/.config/fuzzel/fuzzel.ini
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
    command -v awww-daemon >/dev/null 2>&1 || return 0
    if ! pgrep -x awww-daemon >/dev/null 2>&1; then
        awww-daemon >/dev/null 2>&1 &
        sleep 0.3
    fi
    
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

install_wallpaper_source() {
    local src="$1"

    if is_video_wallpaper "$src"; then
        if ! command -v ffmpeg >/dev/null 2>&1; then
            echo "ffmpeg chybí, video tapetu nelze použít: $src" >&2
            return 1
        fi
        local frame="$STATE_DIR/video-frame.png"
        if ! ffmpeg -y -v error -i "$src" -vf "thumbnail=100" -frames:v 1 -f image2 "$frame" >/dev/null 2>&1; then
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
    local h
    h="$(sha1sum "$CURRENT_WALL" 2>/dev/null)" && printf '%s\n' "${h%% *}" || printf '%s\n' "$CURRENT_WALL"
}

if [[ -n "$WALLPAPER_ARG" ]]; then
    WALLPAPER="$WALLPAPER_ARG"
    [[ -f "$WALLPAPER" ]] || {
        echo "Wallpaper not found: $WALLPAPER" >&2
        exit 1
    }
    install_wallpaper_source "$WALLPAPER" || exit 1
    printf '%s\n' "$WALLPAPER" >"$CURRENT_SOURCE_FILE"
    sig="$(wallpaper_sig)"
    last_sig_file="$STATE_DIR/last-wallpaper.sig"
    if [[ -f "$last_sig_file" ]] && [[ "$(cat "$last_sig_file" 2>/dev/null || true)" == "$sig" ]]; then
        apply_wallpaper_now "$CURRENT_WALL"
        if [[ "${THEME_SKIP_REGEN_IF_SAME_WALLPAPER:-0}" == "1" ]]; then
            notify_msg "Rice" "Wallpaper unchanged — skipping theme regeneration."
            exit 0
        fi
        notify_msg "Rice" "Wallpaper beze zmeny — obnovuju theme."
    fi
else
    if [[ -f "$CURRENT_WALL" ]]; then
        WALLPAPER="$CURRENT_WALL"
    else
        WALLPAPER="$(find "$HOME/Pictures" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null || true)"
        if [[ -z "$WALLPAPER" ]] && command -v magick >/dev/null 2>&1; then
            WALLPAPER="$HOME/Pictures/Wallpapers/rprice-default.png"
            mkdir -p "${WALLPAPER%/*}"
            magick -size 2560x1440 radial-gradient:'#5b3f8c'-'#0d0f1a' "$WALLPAPER" 2>/dev/null || WALLPAPER=""
        fi
        [[ -n "$WALLPAPER" ]] || exit 0
        if [[ "$(readlink -f "$WALLPAPER" 2>/dev/null || printf '%s' "$WALLPAPER")" != "$(readlink -f "$CURRENT_WALL" 2>/dev/null || printf '%s' "$CURRENT_WALL")" ]]; then
            cp -f "$WALLPAPER" "$CURRENT_WALL"
        fi
    fi
    sig="$(wallpaper_sig)"
    last_sig_file="$STATE_DIR/last-wallpaper.sig"
    if [[ -f "$last_sig_file" ]] && [[ "$(cat "$last_sig_file" 2>/dev/null || true)" == "$sig" ]]; then
        if ! pgrep -x awww-daemon >/dev/null 2>&1; then
            apply_wallpaper_now "$WALLPAPER"
        fi
        exit 0
    fi
fi

apply_wallpaper_now "$CURRENT_WALL"
export WALLPAPER_TRANSITION_DONE=1
printf '%s\n' "$(wallpaper_sig)" >"$STATE_DIR/last-wallpaper.sig" 2>/dev/null || true

wal_source="$WALLPAPER"
if [[ -f "$CURRENT_SOURCE_FILE" ]]; then
    source_wall="$(cat "$CURRENT_SOURCE_FILE" 2>/dev/null || true)"
    if [[ -n "$source_wall" && -f "$source_wall" ]]; then
        wal_source="$source_wall"
    fi
fi

if is_video_wallpaper "$wal_source" && [[ -f "$CURRENT_WALL" ]]; then
    wal_source="$CURRENT_WALL"
fi

wal_input="$wal_source"
if command -v magick >/dev/null 2>&1; then
    matugen_png="$STATE_DIR/wal-matugen.png"
    rm -f "$matugen_png"
    magick "${wal_source}[0]" -auto-orient -resize "1920x1920>" "$matugen_png" >/dev/null 2>&1 || true
    [[ -f "$matugen_png" ]] && wal_input="$matugen_png"
fi

is_mono_wallpaper() {
    command -v magick >/dev/null 2>&1 && [[ -f "$1" ]] && rp-theme-colors is-mono "$1"
}

MONO_MODE="${THEME_MONO_MODE:-$("$HOME/.local/bin/rp-settings" get theme.mono_mode 2>/dev/null || echo auto)}"
MATUGEN_ARGS=()
matugen_cfg="$HOME/.config/matugen/config.toml"
case "$MONO_MODE" in
on) IS_MONO=1 ;;
off) IS_MONO=0 ;;
*) if is_mono_wallpaper "$wal_input"; then IS_MONO=1; else IS_MONO=0; fi ;;
esac

_rs="$HOME/.local/bin/rp-settings"
_contrast="$("$_rs" get theme.contrast 2>/dev/null || echo 0.00)"
[[ "$_contrast" != "0.00" ]] && MATUGEN_ARGS+=(--contrast "$_contrast")
if [[ "$IS_MONO" != "1" ]]; then
    MATUGEN_ARGS+=(-t "scheme-$("$_rs" get theme.scheme 2>/dev/null || echo tonal-spot)")
fi

if [[ "$IS_MONO" == "1" ]]; then
    MATUGEN_ARGS+=(-t scheme-monochrome)
    mono_cfg="$(rp-theme-colors mono-config "$matugen_cfg" "$STATE_DIR/templates-mono" 2>/dev/null || true)"
    if [[ -n "$mono_cfg" && -f "$mono_cfg" ]]; then
        matugen_cfg="$mono_cfg"
    fi
fi

palette_json="$STATE_DIR/matugen-palette.json"
: >"$palette_json"
if command -v matugen >/dev/null 2>&1; then
    matugen "${MATUGEN_ARGS[@]}" -c "$matugen_cfg" image "$wal_input" --source-color-index 0 -j hex --dry-run \
        >"$palette_json" 2>/dev/null || true
fi

accent_cfg="$(rp-theme-colors accent-config "$matugen_cfg" "$STATE_DIR/matugen-accent.toml" "$palette_json" \
    "$wal_input" "$("$_rs" get theme.accent2 2>/dev/null || echo auto)" "$IS_MONO" 2>/dev/null || true)"
[[ -n "$accent_cfg" && -f "$accent_cfg" ]] && matugen_cfg="$accent_cfg"

if command -v matugen >/dev/null 2>&1 && [[ -f "$wal_input" ]]; then
    matugen "${MATUGEN_ARGS[@]}" -c "$matugen_cfg" image "$wal_input" --source-color-index 0 2>/dev/null || true
fi

eval "$(rp-theme-colors palette "$palette_json")"

accent="${color5}"
accent_soft="${color6}"
accent_blue="${color4}"
accent_urgent="${color1}"

if [[ -f "$WALLPAPER" ]] && command -v magick >/dev/null 2>&1 \
    && image_pick="$(rp-theme-colors image-accent "$WALLPAPER" 2>/dev/null)"; then
    first="$(sed -n '1p' <<<"$image_pick")"
    second="$(sed -n '2p' <<<"$image_pick")"
    [[ -n "$first" ]] && accent="$first"
    [[ -n "$second" ]] && accent_blue="$second"
fi

: "${accent:=${color5:-#ffb68c}}"
: "${accent_soft:=${color6:-#e5bfaa}}"
: "${accent_blue:=${color4:-#ffb68c}}"
: "${accent_urgent:=${color1:-#ffb4ab}}"
[[ -n "$accent" ]] || accent="#ffb68c"
[[ -n "$accent_soft" ]] || accent_soft="#e5bfaa"
[[ -n "$accent_blue" ]] || accent_blue="#ffb68c"
[[ -n "$accent_urgent" ]] || accent_urgent="#ffb4ab"

export HOME PID_DIR CURRENT_WALL WALLPAPER
export background foreground cursor
export color0 color1 color2 color3 color4 color5 color6 color7 color8 color9 color10 color11 color12 color13 color14 color15
export accent accent_soft accent_blue accent_urgent

snapshot_files
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

    while IFS='|' read -r _priority module; do
        [[ -x "$module" ]] || continue
        base="$(basename "$module")"
        if is_heavy_module "$base"; then
            printf '[async] %s started\n' "$base" >>"$THEME_LOG"
            (
                "$module" >>"$THEME_LOG" 2>&1
                printf '[async] %s done rc=%s\n' "$base" "$?" >>"$THEME_LOG"
            ) &
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
cleanup_snapshots
