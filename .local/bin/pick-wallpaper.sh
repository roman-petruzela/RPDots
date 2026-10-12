#!/usr/bin/env bash
set -euo pipefail

WALL_DIR=""
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/wallpaper-thumbs"
STATE_COLORS="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/colors.sh"
for candidate in "$HOME/Pictures/Wallpapers" "$HOME/.local/share/wallpapers" "$HOME/Pictures"; do
  if [[ -d "$candidate" ]]; then
    WALL_DIR="$candidate"
    break
  fi
done

[[ -n "$WALL_DIR" ]] || exit 0
mkdir -p "$THUMB_DIR"

if [[ -f "$STATE_COLORS" ]]; then
  set +u
  # shellcheck source=/dev/null
  source "$STATE_COLORS"
  set -u
fi
wal_bg="${background:-#0b0909}"
wal_fg="${foreground:-#e3c8a1}"
wal_ac="${accent:-#976D54}"

is_video() {
  case "${1,,}" in
    *.mp4 | *.mkv | *.webm | *.mov | *.avi) return 0 ;;
    *) return 1 ;;
  esac
}

thumb_key_for() {
  local img="$1" ver="$2" sig
  sig="$(stat -c '%Y_%s' "$img" 2>/dev/null || echo "0_0")"
  printf '%s|%s|%s' "$ver" "$img" "$sig" | md5sum | awk '{print $1}'
}

thumb_path_for() { echo "$THUMB_DIR/$(thumb_key_for "$1" v3).png"; }
large_thumb_name() { printf 'large-v1-%s-%s.jpg' "$1" "$(basename "$2")"; }
large_thumb_path_for() {
  echo "$THUMB_DIR/$(large_thumb_name "$(stat -c '%Y_%s' "$1" 2>/dev/null || echo 0_0)" "$1")"
}

make_thumb() {
  local img="$1"
  local thumb large src tmpframe
  thumb="$(thumb_path_for "$img")"
  large="$(large_thumb_path_for "$img")"
  if [[ ( ! -f "$thumb" || ! -f "$large" ) ]] && command -v magick >/dev/null 2>&1; then
    src="$img"
    tmpframe=""
    if is_video "$img"; then
      if command -v ffmpeg >/dev/null 2>&1; then
        tmpframe="${large%.jpg}.src.png"
        ffmpeg -y -v error -i "$img" -vf "thumbnail=100" -frames:v 1 -f image2 "$tmpframe" >/dev/null 2>&1 \
          || ffmpeg -y -v error -i "$img" -frames:v 1 -f image2 "$tmpframe" >/dev/null 2>&1 \
          || tmpframe=""
        [[ -n "$tmpframe" && -f "$tmpframe" ]] && src="$tmpframe" || src=""
      else
        src=""
      fi
    fi
    if [[ -n "$src" ]]; then
      [[ -f "$thumb" ]] || magick "${src}[0]" -auto-orient -thumbnail "240x140^" -gravity center -background "$wal_bg" -extent 240x140 "$thumb" >/dev/null 2>&1 || true
      [[ -f "$large" ]] || { magick "${src}[0]" -auto-orient -thumbnail "960x540^" -gravity center -extent 960x540 -quality 88 "$large.tmp.jpg" >/dev/null 2>&1 \
        && mv -f "$large.tmp.jpg" "$large"; } || rm -f "$large.tmp.jpg"
    fi
    [[ -n "$tmpframe" ]] && rm -f "$tmpframe"
  fi
  if [[ -f "$thumb" ]]; then
    echo "$thumb"
  else
    echo "$img"
  fi
}

list_wallpapers() {
  find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) -print0 | sort -z
}

current_wallpaper_source() {
  cat "${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/current-wallpaper-source" 2>/dev/null || true
}

if [[ "${1:-}" == "--warm-dispatch" ]]; then
  shift
  lock="$THUMB_DIR/.warm-dispatch.lock"
  mkdir "$lock" 2>/dev/null || exit 0
  trap 'rmdir "$lock" 2>/dev/null' EXIT
  for file in "$@"; do
    make_thumb "$file" >/dev/null
  done
  exit 0
fi

warm_missing_thumbs() {
  local file missing=()
  for file in "$@"; do
    [[ -f "$(thumb_path_for "$file")" && -f "$(large_thumb_path_for "$file")" ]] || missing+=("$file")
  done
  [[ "${#missing[@]}" -gt 0 ]] || return 0
  local prefix=()
  command -v ionice >/dev/null 2>&1 && prefix+=(ionice -c3)
  command -v nice >/dev/null 2>&1 && prefix+=(nice -n 19)
  setsid "${prefix[@]}" "$0" --warm-dispatch "${missing[@]}" >/dev/null 2>&1 </dev/null &
}

if [[ "${1:-}" == "--list" ]]; then
  mapfile -d '' files < <(list_wallpapers)
  [[ "${#files[@]}" -gt 0 ]] || exit 0
  mapfile -t sigs < <(stat -c '%Y_%s' -- "${files[@]}")
  current_src="$(current_wallpaper_source)"
  shown_file="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/wallpaper-shown"
  [[ -e "$shown_file" ]] || : >"$shown_file"
  missing=()
  for i in "${!files[@]}"; do
    file="${files[$i]}"
    large="$THUMB_DIR/large-v1-${sigs[$i]}-${file##*/}.jpg"
    [[ -f "$large" ]] || missing+=("$file")
    kind=image
    is_video "$file" && kind=video
    current=0
    [[ "$file" == "$current_src" ]] && current=1
    printf '%s\t%s\t%s\t%d\n' "$file" "$large" "$kind" "$current"
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    prefix=()
    command -v ionice >/dev/null 2>&1 && prefix+=(ionice -c3)
    command -v nice >/dev/null 2>&1 && prefix+=(nice -n 19)
    setsid "${prefix[@]}" "$0" --warm-dispatch "${missing[@]}" >/dev/null 2>&1 </dev/null &
  fi
  exit 0
fi

if [[ "${1:-}" != "--rofi" ]] && "$HOME/.local/bin/rp-shell" wallpaper toggle; then
  exit 0
fi

pick_wallpaper() {
  local selected=""
  if command -v rofi >/dev/null 2>&1; then
    mapfile -d '' files < <(list_wallpapers)
    [[ "${#files[@]}" -gt 0 ]] || { echo ""; return; }
    local current_src=""
    local current_index=""
    current_src="$(current_wallpaper_source)"
    local rofi_theme
    rofi_theme='
      * {
        bg: '"${wal_bg}"'ee;
        bg-alt: '"${wal_bg}"'cc;
        fg: '"${wal_fg}"'ff;
        ac: '"${wal_ac}"'ff;
      }
      window { width: 46%; border: 2px; border-color: @ac; border-radius: 12px; background-color: @bg; }
      mainbox { padding: 8px; spacing: 6px; }
      inputbar { padding: 6px; border-radius: 8px; background-color: @bg-alt; }
      prompt { text-color: @ac; }
      entry { text-color: @fg; background-color: transparent; }
      textbox, textbox-prompt-colon { text-color: @fg; background-color: transparent; }
      listview { lines: 6; columns: 1; spacing: 4px; scrollbar: false; }
      element { padding: 4px; border-radius: 8px; background-color: transparent; }
      element normal.normal, element normal.urgent, element normal.active, element alternate.normal, element alternate.urgent, element alternate.active { background-color: transparent; }
      element selected.normal, element selected.urgent, element selected.active { background-color: @bg-alt; border: 1px; border-color: @ac; }
      element-text { vertical-align: 0.5; text-color: @fg; }
      element-text selected { text-color: @ac; }
      element-text active { text-color: @ac; }
      element-icon { size: 72px; border-radius: 6px; }
    '
    for i in "${!files[@]}"; do
      file="${files[$i]}"
      if [[ -n "$current_src" && "$file" == "$current_src" ]]; then
        current_index="$i"
      fi
    done
    warm_missing_thumbs "${files[@]}"
    build_entries() {
      local file base thumb
      for file in "${files[@]}"; do
        base="$(basename "$file")"
        thumb="$(thumb_path_for "$file")"
        if [[ -f "$thumb" ]]; then
          printf '%s\0icon\x1f%s\n' "$base" "$thumb"
        else
          printf '%s\n' "$base"
        fi
      done
    }
    if [[ -n "$current_index" ]]; then
      selected="$(build_entries | rofi -dmenu -i -p "Wallpaper" -mesg "Fuzzel-style + náhled" \
          -show-icons -no-config -theme-str "$rofi_theme" -a "$current_index")"
    else
      selected="$(build_entries | rofi -dmenu -i -p "Wallpaper" -mesg "Fuzzel-style + náhled" \
          -show-icons -no-config -theme-str "$rofi_theme")"
    fi
    if [[ -n "${selected:-}" ]]; then
      selected="$WALL_DIR/$selected"
    fi
  elif command -v zenity >/dev/null 2>&1; then
    selected="$(zenity --file-selection --title="Vyber tapetu" --filename="$WALL_DIR/" --file-filter="Wallpapers | *.jpg *.jpeg *.png *.webp *.gif *.mp4 *.mkv *.webm" 2>/dev/null || true)"
  elif command -v fuzzel >/dev/null 2>&1; then
    local choice
    choice="$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) -printf '%f\n' | sort | fuzzel --dmenu --prompt='Wallpaper: ' || true)"
    if [[ -n "${choice:-}" ]]; then
      selected="$WALL_DIR/$choice"
    fi
  fi
  echo "$selected"
}

wallpaper="$(pick_wallpaper)"
[[ -n "${wallpaper:-}" ]] || exit 0

exec "$HOME/.local/bin/apply-wallpaper-theme.sh" "$wallpaper"
