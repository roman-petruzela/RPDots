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

# Cesta k náhledu je odvozená jen z cesty/mtimu/velikosti souboru — žádné IO,
# žádná závislost na aktuální barvě motivu. Dřív byl v klíči i wal_bg, jenže
# -background se u neprůhledných zdrojů (drtivá většina) vůbec neprojeví
# (thumbnail ...^ + -extent vždy zaplní celou plochu, není co podbarvovat) —
# takže každá změna tapety kvůli barvě motivu zneplatnila cache úplně všem
# ostatním tapetám a picker je musel při příštím otevření přegenerovat znovu.
thumb_key_for() {
  local img="$1" ver="$2" sig
  sig="$(stat -c '%Y_%s' "$img" 2>/dev/null || echo "0_0")"
  printf '%s|%s|%s' "$ver" "$img" "$sig" | md5sum | awk '{print $1}'
}

# Malý náhled pro rofi (fallback), velký 16:9 pro quickshell coverflow —
# prostřední karta je přes 800 px široká, 240px náhled by na ní byl rozmazaný.
# Velký náhled nemá md5 klíč, ale čitelné jméno z mtime/velikosti/názvu —
# --list ho tak spočítá pro celý adresář jedním `stat`, bez podprocesu na
# soubor (s md5sum trvalo otevření pickeru se 100 tapetami přes 1,5 s).
# Adresář se prochází jen do hloubky 1, takže basename je jednoznačný.
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
    # ImageMagick umí mp4 jen přes ffmpeg delegáta, který nemusí být k dispozici —
    # u videa si snímek vytáhneme sami (jednou pro obě velikosti).
    if is_video "$img"; then
      if command -v ffmpeg >/dev/null 2>&1; then
        tmpframe="${large%.jpg}.src.png"
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
      [[ -f "$thumb" ]] || magick "$src[0]" -auto-orient -thumbnail "240x140^" -gravity center -background "$wal_bg" -extent 240x140 "$thumb" >/dev/null 2>&1 || true
      # Zápis přes .tmp + mv: quickshell soubor načítá, jakmile existuje, a
      # napůl zapsaný JPEG by se mu zobrazil jako useknutý obrázek.
      [[ -f "$large" ]] || { magick "$src[0]" -auto-orient -thumbnail "960x540^" -gravity center -extent 960x540 -quality 88 "$large.tmp.jpg" >/dev/null 2>&1 \
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

# Interní režim: sériově vygeneruje chybějící náhledy na pozadí a skončí.
# Zámek přes mkdir (atomický) zaručuje, že běží nanejvýš jeden dispatcher
# najednou — bez něj by opakované spuštění pick-wallpaper.sh (např. víc
# stisků Mod+Shift+W dřív, než doběhne první vlna) odpálilo další a další
# souběžné vlny ffmpeg/magick přes desítky video tapet najednou a spolehlivě
# to sundá celý systém (přesně tohle se stalo — proto sériově, ne paralelně,
# a proto zámek, ne jen "spustit na pozadí").
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

# Rozjede generování chybějících náhledů jedním low-priority procesem na
# pozadí, nečeká na něj. Menu se tak otevře okamžitě s tím, co je v cache —
# chybějící náhledy se dotáhnou postupně, jeden po druhém, příště. Priorita
# je název (vidíš ho hned), náhled je jen bonus.
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

# Výpis pro quickshell picker (WallpaperPicker.qml), jeden řádek na tapetu:
#   cesta \t velký náhled \t image|video \t 1 když je aktuální, jinak 0
# Náhled nemusí ještě existovat — picker ho zkouší načíst znovu, dokud ho
# warm_missing_thumbs na pozadí nedogeneruje.
if [[ "${1:-}" == "--list" ]]; then
  mapfile -d '' files < <(list_wallpapers)
  [[ "${#files[@]}" -gt 0 ]] || exit 0
  mapfile -t sigs < <(stat -c '%Y_%s' -- "${files[@]}")
  current_src="$(current_wallpaper_source)"
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
  # Dispatcher vyrobí i malý rofi náhled; tady se kvůli rychlosti hlídá jen velký.
  if [[ "${#missing[@]}" -gt 0 ]]; then
    prefix=()
    command -v ionice >/dev/null 2>&1 && prefix+=(ionice -c3)
    command -v nice >/dev/null 2>&1 && prefix+=(nice -n 19)
    setsid "${prefix[@]}" "$0" --warm-dispatch "${missing[@]}" >/dev/null 2>&1 </dev/null &
  fi
  exit 0
fi

# Výchozí cesta je quickshell coverflow (WallpaperPicker.qml) — ten po výběru
# sám spustí apply-wallpaper-theme.sh. Rofi zůstává jako fallback, když qs
# neběží nebo ještě nemá načtený IPC cíl `wallpaper` (--rofi ho vynutí).
if [[ "${1:-}" != "--rofi" ]] && command -v qs >/dev/null 2>&1 \
  && qs ipc call wallpaper toggle >/dev/null 2>&1; then
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
    # Jen z cache, bez volání make_thumb — název je vždy hned k dispozici,
    # náhled se přidá jen když je už hotový (viz warm_missing_thumbs výš).
    # Musí jít přímo rourou do rofi, ne přes proměnnou — $(...) v bashi tiše
    # zahazuje NUL byty, takže by se ztratil oddělovač name\0icon\x1fpath a
    # rofi by celý řádek (včetně "iconpath") vypsal jako holý text.
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
