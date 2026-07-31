# dotfiles

Niri rice na Arch Linuxu / CachyOS.

## Stack

| Komponenta | Software |
|---|---|
| Compositor | [niri](https://github.com/YaLTeR/niri) |
| Status bar | [waybar](https://github.com/Alexays/Waybar) |
| Terminál | [kitty](https://github.com/kovidgoyal/kitty) |
| Launcher | [fuzzel](https://codeberg.org/dnkl/fuzzel) |
| Notifikace | [mako](https://github.com/emersion/mako) |
| Zamykání | [swaylock-effects](https://github.com/mortie/swaylock-effects) |
| Tapeta | [awww](https://github.com/heather7283/awww) |
| Barevné téma | [pywal](https://github.com/dylanaraps/pywal) |
| Shell | zsh + oh-my-zsh + powerlevel10k |
| Displeje | kanshi |

## Instalace

```bash
git clone https://github.com/roman-petruzela/dotfiles ~/dotfiles
cd ~/dotfiles
sudo pacman -S stow
./install.sh
```

## Struktura

```
dotfiles/
├── .config/
│   ├── niri/          # Compositor config
│   ├── waybar/        # Status bar
│   ├── kitty/         # Terminál
│   ├── mako/          # Notifikace
│   ├── fuzzel/        # Launcher
│   ├── swaylock/      # Screen lock
│   ├── kanshi/        # Display management
│   ├── cava/          # Audio visualizer
│   ├── btop/          # System monitor
│   ├── rofi/          # App menu
│   ├── fastfetch/     # System info
│   └── niri-rice/     # Theming modules
├── .local/bin/        # Scripty
├── .zshrc
├── .p10k.zsh
└── install.sh
```

## Klávesové zkratky

| Zkratka | Akce |
|---|---|
| `Mod+T` | Terminál (kitty) |
| `Mod+D` | Launcher (fuzzel) |
| `Mod+Q` | Zavřít okno |
| `Mod+Shift+W` | Vybrat tapetu |
| `Mod+Shift+S` | Screenshot |
| `Super+Alt+L` | Zamknout |
| `Mod+H/J/K/L` | Navigace oken |
| `Mod+1-9` | Přepínat workspace |
