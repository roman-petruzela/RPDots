# RPRice — Arch dotfiles

Niri rice na Arch Linuxu / CachyOS s glassmorphism estetikou a Material You barvami.

## Stack

| Komponenta | Software |
|---|---|
| Compositor | [niri](https://github.com/YaLTeR/niri) |
| Status bar | [waybar](https://github.com/Alexays/Waybar) |
| Dashboard / OSD | [quickshell](https://quickshell.outfoxxed.me/) |
| Terminál | [kitty](https://github.com/kovidgoyal/kitty) |
| Launcher | [fuzzel](https://codeberg.org/dnkl/fuzzel) |
| Notifikace | [mako](https://github.com/emersion/mako) |
| Zamykání | [swaylock-effects](https://github.com/mortie/swaylock-effects) |
| Tapeta | [awww](https://github.com/heather7283/awww) |
| Barevné téma | [matugen](https://github.com/InioX/matugen) (Material You) |
| Správce souborů | [Thunar](https://docs.xfce.org/xfce/thunar/start) |
| Shell | zsh + oh-my-zsh + powerlevel10k |
| Displeje | kanshi |

## Barevný pipeline

Při změně tapety (`Mod+Shift+W`) se automaticky:
1. Vygeneruje Material You paleta pomocí `matugen`
2. Přegenerují konfigurace: waybar, kitty, mako, fuzzel, gtk
3. Reload waybar (SIGUSR2), mako, quickshell, GTK apps

### GTK3 / Thunar

GTK3 čte `~/.config/gtk-3.0/gtk.css` jen jednou při startu aplikace, takže přes něj
nejde přebarvovat za běhu. Barvy proto jdou do **pojmenovaného tématu** `RPRice`
(`~/.local/share/themes/RPRice/`), které GTK3 znovu načte z disku pokaždé, když se
změní název tématu:

```
templates/gtk3-light.css  ─matugen─▶  themes/RPRice/gtk-3.0/gtk.css       (světlá varianta)
templates/gtk3-dark.css   ─matugen─▶  themes/RPRice/gtk-3.0/gtk-dark.css  (tmavá varianta)
                                      themes/RPRice/gtk-3.0/widgets.css   (statická pravidla)
```

Vygenerované soubory naimportují Adwaitu (struktura widgetů), pak paletu z tapety,
pak `widgets.css` s pravidly pro Thunar. `gtk-live-reload.sh` přepne téma na Adwaitu
a zpět, čímž se běžící okna přebarví bez restartu. Světlou/tmavou variantu vybírá
`theme-modules/61-thunar.sh` podle jasu tapety.

Material 3 drží tmavé povrchy skoro neutrální, což vedle Adwaity vypadá jako obyčejná
šedá. `widgets.css` proto primární barvu do povrchů zpátky přimíchává — síla se ladí
na jednom místě nahoře v souboru:

```css
@define-color rp_surface  alpha(mix(@m3_surface_container, @m3_primary, 0.22), 0.80);
@define-color rp_sel      mix(@m3_primary_container, @m3_primary, 0.45);
```

`mix(..., N)` řídí barevnost (vyšší = výraznější, `0` = čisté M3 povrchy),
`alpha(..., N)` průhlednost. Průhlednost je záměrně jen na pozadích — text zůstává
ostrý, na rozdíl od `opacity` v niri. Menu a výběr zůstávají krycí kvůli čitelnosti.

Pozor: `widgets.css` je připojený přes `@import` a ten se při přepnutí tématu znovu
nenačítá — po zásahu do něj je potřeba `thunar -q`. Změna tapety (a tedy palety
v `gtk-dark.css`) se naopak projeví živě.

Náhledy obstarává `tumbler` (bez něj Thunar negeneruje žádné) — `ffmpegthumbnailer`
přidává videa, `poppler-glib` PDF, `libgsf` dokumenty. Připojování disků a telefonů
řeší `gvfs` + `gvfs-smb` (síť) a `gvfs-afc` (iOS).

Thunar navíc potřebuje `xfce4-settings` — dodává `xfce4-mime-helper`, bez kterého
nefunguje „Open Terminal Here" (terminál se vybírá v `.config/xfce4/helpers.rc`).

## Klávesové zkratky

| Zkratka | Akce |
|---|---|
| `Mod+T` | Terminál (kitty) |
| `Mod+D` | Launcher (fuzzel) |
| `Mod+Q` | Zavřít okno |
| `Mod+Shift+W` | Vybrat tapetu + aplikovat téma |
| `Mod+Shift+D` | Dashboard (quickshell) |
| `Mod+Shift+S` | Screenshot |
| `Super+Alt+L` | Zamknout |
| `Mod+H/J/K/L` | Navigace oken |
| `Mod+1-9` | Přepínat workspace |

## Instalace

```bash
git clone https://github.com/roman-petruzela/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Struktura

```
dotfiles/
├── .config/
│   ├── niri/          # Compositor
│   ├── waybar/        # Status bar
│   ├── quickshell/    # Dashboard + OSD
│   ├── matugen/       # Color pipeline (templates)
│   ├── kitty/         # Terminál
│   ├── mako/          # Notifikace
│   ├── fuzzel/        # Launcher
│   ├── swaylock/      # Screen lock
│   ├── kanshi/        # Display management
│   ├── cava/          # Audio visualizer
│   ├── btop/          # System monitor
│   ├── fastfetch/     # System info
│   ├── Thunar/        # Správce souborů (custom actions)
│   ├── gtk-3.0/       # GTK3 settings (téma, ikony, kurzor)
│   └── xfce4/         # helpers.rc — výchozí terminál pro Thunar
├── .local/
│   ├── bin/           # Skripty (theming, OSD, wallpaper)
│   └── share/themes/  # RPRice GTK3 téma (barvy generuje matugen)
├── .zshrc
├── .p10k.zsh
└── install.sh
```
