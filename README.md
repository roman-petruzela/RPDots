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
| Shell | zsh + oh-my-zsh + powerlevel10k |
| Displeje | kanshi |

## Barevný pipeline

Při změně tapety (`Mod+Shift+W`) se automaticky:
1. Vygeneruje Material You paleta pomocí `matugen`
2. Přegenerují konfigurace: waybar, kitty, mako, fuzzel, gtk
3. Reload waybar (SIGUSR2), mako, quickshell

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
│   └── fastfetch/     # System info
├── .local/bin/        # Skripty (theming, OSD, wallpaper)
├── .zshrc
├── .p10k.zsh
└── install.sh
```
