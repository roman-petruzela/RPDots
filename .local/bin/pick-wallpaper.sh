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

# Barvy generuje matugen (šablona ~/.config/matugen/templates/colors.sh).
# Dřív se braly z pywalu, ten se už nepoužívá.
if [[ -f "$STATE_COLORS" ]]; then
  set +u
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

make_thumb() {
  local img="$1"
  local sig key thumb src tmpframe
  sig="$(stat -c '%Y_%s' "$img" 2>/dev/null || echo "0_0")"
  key="$(printf 'v2|%s|%s|%s' "$img" "$sig" "$wal_bg" | md5sum | awk '{print $1}')"
  thumb="$THUMB_DIR/$key.png"
  if [[ ! -f "$thumb" ]] && command -v magick >/dev/null 2>&1; then
    src="$img"
    tmpframe=""
    # ImageMagick umí mp4 jen přes ffmpeg delegáta, který nemusí být k dispozici —
    # u videa si snímek vytáhneme sami.
    if is_video "$img"; then
      if command -v ffmpeg >/dev/null 2>&1; then
        tmpframe="$THUMB_DIR/$key.src.png"
        # thumbnail=100 vybere reprezentativní snímek — u videí s fade-in z černé
        # by prostý první snímek dal černý náhled.
        ffmpeg -y -v error -i "$img" -vf "thumbnail=100" -frames:v 1 -f image2 "$tmpframe" >/dev/null 2>&1 \
          || ffmpeg -y -v error -i "$img" -frames:v 1 -f image2 "$tmpframe" >/dev/null 2>&1 \
          || tmpframe=""
        [[ -n "$tmpframe" && -f "$tmpframe" ]] && src="$tmpframe" || src=""
      else
        src=""
      fi
    fi
    if [[ -n "$src" ]]; then
      magick "$src[0]" -auto-orient -thumbnail "240x140^" -gravity center -background "$wal_bg" -extent 240x140 "$thumb" >/dev/null 2>&1 || true
    fi
    [[ -n "$tmpframe" ]] && rm -f "$tmpframe"
  fi
  if [[ -f "$thumb" ]]; then
    echo "$thumb"
  else
    echo "$img"
  fi
}

pick_wallpaper() {
  local selected=""
  if command -v rofi >/dev/null 2>&1; then
    mapfile -d '' files < <(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \) -print0 | sort -z)
    [[ "${#files[@]}" -gt 0 ]] || { echo ""; return; }
    local current_src=""
    local current_index=""
    if [[ -f "${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/current-wallpaper-source" ]]; then
      current_src="$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice/current-wallpaper-source" 2>/dev/null || true)"
    fi
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
    if [[ -n "$current_index" ]]; then
      selected="$(
        for file in "${files[@]}"; do
          base="$(basename "$file")"
          thumb="$(make_thumb "$file")"
          printf '%s\0icon\x1f%s\n' "$base" "$thumb"
        done | rofi -dmenu -i -p "Wallpaper" -mesg "Fuzzel-style + náhled" \
          -show-icons -no-config -theme-str "$rofi_theme" -a "$current_index"
      )"
    else
      selected="$(
        for file in "${files[@]}"; do
          base="$(basename "$file")"
          thumb="$(make_thumb "$file")"
          printf '%s\0icon\x1f%s\n' "$base" "$thumb"
        done | rofi -dmenu -i -p "Wallpaper" -mesg "Fuzzel-style + náhled" \
          -show-icons -no-config -theme-str "$rofi_theme"
      )"
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
