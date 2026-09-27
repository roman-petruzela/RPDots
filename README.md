# RPRice — Arch dotfiles

A niri rice for Arch / CachyOS. Material You colours generated from the wallpaper, one shell in quickshell (bar, dashboard, launcher, settings, OSD).

## Stack

| | |
|---|---|
| Compositor | [niri](https://github.com/YaLTeR/niri) |
| Shell (bar, dashboard, launcher, settings, OSD, polkit) | [quickshell](https://quickshell.outfoxxed.me/) (waybar as the alternative bar) |
| Terminal | kitty |
| Notifications | mako |
| Lock / login | swaylock-effects / greetd + quickshell greeter |
| Wallpaper | awww (images), mpvpaper (video) |
| Colours | matugen |
| Files | Thunar, yazi |
| Shell | zsh + oh-my-zsh + powerlevel10k |

## Install

```bash
git clone https://github.com/roman-petruzela/RPRice ~/dotfiles
cd ~/dotfiles
./install.sh
```

- Run it as your normal user. It asks for the sudo password once and refuses to run as root.
- It runs a full `pacman -Syu`, because Arch doesn't support partial upgrades. pacman and paru run with `--noconfirm`. paru is installed automatically if it is missing.
- The optional extras (OCR, gamemode, qt5ct, atuin, neovim, yazi…, about 350 MB) are offered once at the start.
- Configs are **copied** into `$HOME`. Changed files are backed up to `~/.cache/niri-rice/deploy-backup/`. Option 5 symlinks them with stow instead.
- A GitHub ZIP (without `.git`) works too.

After the first login into niri, a theme is generated from the first picture in `~/Pictures`. With no pictures, a default gradient is created.

**Log in with `niri-session`, or through the login screen (greetd).** Plain `niri` from a TTY also works, because `start-rice-services.sh` then imports the environment into systemd and starts `niri-rice-session.target`.

### System parts (option 6, optional)

| | |
|---|---|
| `~/.local/share/rp-power/install.sh` | power modes: sudoers rule for the helper, udev rule on AC plug/unplug |
| `~/.local/share/rp-greeter/install.sh` | quickshell login screen on greetd, replacing the current display manager (`--revert` goes back) |
| `~/.local/share/rp-lightdm-sync/install.sh` | theme and wallpaper for the LightDM greeter (only offered when LightDM is installed) |

## Keybindings

| | |
|---|---|
| `Mod+T` | Terminal |
| `Mod+D` | Launcher |
| `Mod+S` | Settings |
| `Mod+Shift+D` | Dashboard |
| `Mod+Shift+W` | Wallpaper picker + theme |
| `Mod+Shift+E` | Session menu |
| `Mod+Ctrl+V` | Clipboard history |
| `Mod+E` | Files (yazi) |
| `Mod+Q` | Close window |
| `Alt+Tab`, ``Alt+` `` | Window switcher (all / focused app) |
| `Mod+Tab` | Workspace switcher |
| `Mod+O` | Overview |
| `Mod+Shift+O` / `Mod+Ctrl+O` | Audio output switcher / next output |
| `Mod+Shift+S` | Screenshot |
| `Super+Alt+L` | Lock |
| `Mod+H/J/K/L`, `Mod+1-9` | Focus, workspaces |

## How it fits together

**Colours.** `apply-wallpaper-theme.sh` → matugen renders `.config/matugen/templates/*` → `.local/bin/theme-modules/NN-*.sh` apply and reload each app in order. Always go through the script: matugen's own `run_after` does not fire here. Generated files (Colors.js, colors.css, …) are gitignored. Their source is always the template. The same surface-colour formula is repeated in `gtk3-dark.css`, `zed-theme.json` and `spicetify-user.css`, so change all three together.

**Settings and generated config.** The Settings window only renders. The `rp-*` CLIs in `.local/bin/` hold the logic and write the gitignored files:

| | |
|---|---|
| `rp-settings` | schema + `settings.json` → `niri/settings.kdl`, kitty, mako, swayidle. Flags like `tap` or `natural-scroll` live only in settings.kdl, because a niri include can't turn a flag off |
| `rp-display` | monitors → `niri/displays.kdl` + kanshi config |
| `rp-power` | CPU/dGPU/animation profiles. The animation KDL is a heredoc inside the script |
| `rp-audio` | one volume mirrored to every output, and output switching (also [its own repo](https://github.com/roman-petruzela/rp-audio)) |
| `rp-net`, `rp-sys`, `rp-keys`, `rp-apps`, `rp-history` | backends of the other Settings pages |
| `rp-shell` | sends commands to the running quickshell over a socket |
| `rp-bar` | quickshell bar or waybar |
| `rp-job` | detached root jobs whose log survives a quickshell reload |

**Always-on pieces** are systemd user units in `.config/systemd/user/` (quickshell, audio sync, cliphist, wallpaper healthcheck, waybar watchdog). They are started by `start-rice-services.sh` from niri's `spawn-at-startup`.

## Known quirks

- **polkit:** three failed or cancelled polkit prompts lock the account for 10 minutes (faillock). Settings therefore reads firewalld through D-Bus and asks for a password once per write.
- **Blur:** blur behind a fading popup flashes at full size, so bar popups have no blur. The launcher and Settings are niri toplevels animated by niri.
- **quickshell IPC:** an `IpcHandler` function must not be named `show`. `qs ipc call` can't pass arguments, so widgets read their own state.
- **Flyouts on several monitors:** the target screen has to be set before the window is shown (`FocusedOutput.qml`), otherwise the window jumps between monitors.
- **GTK3:** reads its theme only at startup. Colours go into the `RPRice` theme and `gtk-live-reload.sh` flips the theme name. `widgets.css` needs `thunar -q`.

## Layout

```
.config/
  niri/            compositor (config.kdl + generated settings.kdl, displays.kdl)
  quickshell/      shell.qml, bar/, dash/, settings/ (Settings pages), popups
  matugen/         colour templates
  systemd/user/    always-on units
  waybar/ kitty/ mako/ fuzzel/ swaylock/ wireplumber/ Thunar/ …
.local/bin/        rp-* backends, theme scripts, theme-modules/
.local/share/      RPRice GTK theme, rp-power / rp-greeter / rp-lightdm-sync (root parts)
install.sh
```
