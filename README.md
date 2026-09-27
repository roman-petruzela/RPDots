# RPRice

Dotfiles for a [niri](https://github.com/YaLTeR/niri) desktop on Arch Linux and CachyOS. Colours are generated from the wallpaper with matugen; the bar, dashboard, launcher, settings and login screen are built in [quickshell](https://quickshell.outfoxxed.me/).

## Components

| | |
|---|---|
| Compositor | niri |
| Shell | quickshell (waybar available as an alternative bar) |
| Terminal | kitty |
| Notifications | mako |
| Lock screen | swaylock-effects |
| Login screen | greetd with a quickshell greeter (optional) |
| Wallpaper | awww, mpvpaper for video |
| Theming | matugen |
| File managers | Thunar, yazi |
| Shell | zsh, oh-my-zsh, powerlevel10k |

## Installation

```bash
git clone https://github.com/roman-petruzela/RPRice ~/dotfiles
cd ~/dotfiles
./install.sh
```

Run the installer as a regular user; it requests sudo once. It performs a full system upgrade, installs the packages (AUR via paru, installed if missing), deploys the configuration to `$HOME` and backs up any file it replaces to `~/.cache/niri-rice/deploy-backup/`.

Log in with `niri-session` or through a display manager. The theme is generated on first login from the first image in `~/Pictures`, or from a default gradient.

### Optional system components

Available from the installer's *System integration* option:

- **Power profiles** (`rp-power`): CPU, GPU and animation profiles, switched automatically on AC plug/unplug.
- **Login screen** (`rp-greeter`): replaces the current display manager with greetd. Revert with `~/.local/share/rp-greeter/install.sh --revert`.
- **LightDM theme** (`rp-lightdm-sync`): offered when LightDM is installed.

## Key bindings

| | |
|---|---|
| `Mod+T` | Terminal |
| `Mod+D` | Launcher |
| `Mod+S` | Settings |
| `Mod+Shift+D` | Dashboard |
| `Mod+Shift+W` | Wallpaper and theme |
| `Mod+Shift+E` | Session menu |
| `Mod+Ctrl+V` | Clipboard history |
| `Mod+E` | File manager |
| `Mod+Q` | Close window |
| `Alt+Tab` | Window switcher |
| `Mod+Tab` | Workspace switcher |
| `Mod+O` | Overview |
| `Mod+Shift+O` | Audio output |
| `Mod+Shift+S` | Screenshot |
| `Super+Alt+L` | Lock |

## Structure

```
.config/
  niri/            compositor configuration
  quickshell/      bar, dashboard, launcher, settings, popups
  matugen/         colour templates
  systemd/user/    background services
.local/bin/        rp-* command-line backends and theming scripts
.local/share/      GTK theme and optional system components
install.sh
```

The Settings window is a front end for the `rp-*` tools in `.local/bin/`, which write the generated configuration (`settings.kdl`, `displays.kdl` and others). `rp-audio` is also available as a [standalone project](https://github.com/roman-petruzela/rp-audio).
