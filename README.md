# RPRice — Arch dotfiles

Niri rice for Arch / CachyOS. Glassmorphism, Material You colors generated from the wallpaper.

## Stack

| | |
|---|---|
| Compositor | [niri](https://github.com/YaLTeR/niri) |
| Bar | [waybar](https://github.com/Alexays/Waybar) |
| Dashboard / OSD | [quickshell](https://quickshell.outfoxxed.me/) |
| Terminal | [kitty](https://github.com/kovidgoyal/kitty) |
| Launcher | [fuzzel](https://codeberg.org/dnkl/fuzzel) |
| Notifications | [mako](https://github.com/emersion/mako) |
| Lock | [swaylock-effects](https://github.com/mortie/swaylock-effects) |
| Wallpaper | [awww](https://github.com/heather7283/awww) |
| Colors | [matugen](https://github.com/InioX/matugen) |
| Files | [Thunar](https://docs.xfce.org/xfce/thunar/start) |
| Shell | zsh + oh-my-zsh + powerlevel10k |
| Displays | kanshi |

## Color pipeline

`Mod+Shift+W` runs `~/.local/bin/apply-wallpaper-theme.sh`:

```
wallpaper ──▶ matugen ──▶ templates/*  ──▶ theme-modules/NN-*.sh  (apply + reload)
```

Always go through `apply-wallpaper-theme.sh`. Running `matugen` directly skips
the modules — `matugen`'s own `run_after` list does **not execute** in this
version (verified with an isolated probe), so it is dead weight and everything
real lives in `theme-modules/`.

Surface colors are pinned in the templates: lightness and saturation are
constants, only the hue follows the wallpaper.

```css
@define-color rp_view_base {{ colors.primary_container.dark.hex | to_color
                              | set_lightness: 18 | set_saturation: 30 }};
```

The base is `primary_container`, not `primary` — in a dark scheme `primary` is a
pale pastel and only adds lightness, so surfaces still look grey.

The same `set_lightness` / `set_saturation` pairs appear in **three** templates:
`gtk3-dark.css`, `zed-theme.json`, `spicetify-user.css`. Change one, change all
three. matugen has no `mix()` filter, so a shared expression is the only way to
keep the apps byte-identical.

## Tuning

| What | Where | Now |
|---|---|---|
| **Spotify opacity** | `.config/niri/config.kdl` → `window-rule` matching `spotify` → `opacity` | `0.75` |
| Terminal opacity | `.config/kitty/kitty.conf` → `background_opacity` | `0.75` |
| GTK / Thunar alphas | `.local/share/themes/RPRice/gtk-3.0/widgets.css` (top of file) | `rp_window` 0.55, `rp_view` 0.46 |
| Zed alphas | `.config/matugen/templates/zed-theme.json` → `set_alpha` | 0.55 / 0.46 |
| Surface tones | `templates/gtk3-dark.css`, `zed-theme.json`, `spicetify-user.css` | `set_lightness` / `set_saturation` |
| kitty background darkening | `.local/bin/kitty-theme-postprocess.sh` | 50 % HSV value |

GTK alphas stack (the window sits under everything), so the effective opacity is
`1-(1-0.55)(1-0.46) ≈ 0.76` for the file list and `≈ 0.80` for chrome — both aimed
at kitty's `0.75`. Lowering `rp_window` lightens the whole window at once.

## Notes

**GTK3** reads `~/.config/gtk-3.0/gtk.css` once at startup, so colors go into a
*named theme* (`~/.local/share/themes/RPRice/`) instead. `gtk-live-reload.sh`
flips the theme name to Adwaita and back to repaint running windows.
`theme-modules/61-thunar.sh` picks the light or dark variant by wallpaper
brightness.

`widgets.css` is pulled in via `@import`, which is **not** re-read on a theme
switch — after editing it, restart with `thunar -q`. Palette changes in
`gtk-dark.css` do apply live.

Dialogs, menus and popovers stay near-opaque on purpose: their text sits directly
on the window background and is unreadable at 0.75 over a busy wallpaper.

**Zed** needs `"background.appearance": "transparent"` plus
`draw-border-with-background false` in niri — otherwise niri's focus ring is
drawn behind the transparent background and transparency appears to vanish on
focus. Vesktop has the same issue for the same reason (`frameless: true` = CSD).

**Spotify** cannot do real transparency. Vesktop can because it is Electron and
sets `transparent: true`, which gives it a window with an alpha channel; CSS then
just uncovers it. Spotify is CEF and offers no such switch — the window stayed
opaque under XWayland + `--enable-transparent-visuals`, under native Wayland
(`--ozone-platform=wayland`), and with `--default-background-color=00000000`
(measured as pixel correlation with the wallpaper, `r ≈ -0.06`). So niri
`opacity` does it instead, which also fades the text — the compositor only sees
finished pixels and cannot tell text from background.

Painting a blurred copy of the wallpaper into `#main` as a `data:` URI was tried
and works (`file:///` is blocked by CSP), but looked worse and was dropped.

`theme-modules/80-spicetify.sh`: uses `-n` (`--no-restart`) when Spotify is not
running, otherwise every wallpaper change would launch it. When it is running,
the workspace index and output are recorded and restored afterwards. The restart
is async — the command returns, the old window lives ~2.6 s longer and the
replacement appears ~2.9 s after the return — so the script waits for a window
with a **different** id.

**Vesktop** colors are generated to `quickCss.generated.css` and copied over
`quickCss.css` with `cat` by `70-vesktop.sh`. matugen *replaces* files, creating
a new inode and breaking the inotify watch Vencord holds on `quickCss.css`.

**Thunar** needs `xfce4-settings` for `xfce4-mime-helper` ("Open Terminal Here",
configured in `.config/xfce4/helpers.rc`), `tumbler` for thumbnails
(`ffmpegthumbnailer` for video, `poppler-glib` for PDF, `libgsf` for documents),
and `gvfs` + `gvfs-smb` / `gvfs-afc` for mounting.

## Keybindings

| | |
|---|---|
| `Mod+T` | Terminal |
| `Mod+D` | Launcher |
| `Mod+E` | Files (yazi) |
| `Mod+Q` | Close window |
| `Mod+Shift+W` | Pick wallpaper + apply theme |
| `Mod+Shift+D` | Dashboard |
| `Mod+Shift+S` | Screenshot |
| `Super+Alt+L` | Lock |
| `Mod+H/J/K/L` | Focus windows |
| `Mod+1-9` | Workspaces |

## Install

```bash
git clone https://github.com/roman-petruzela/RPRice ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Layout

```
dotfiles/
├── .config/
│   ├── niri/          # compositor
│   ├── waybar/        # bar
│   ├── quickshell/    # dashboard + OSD
│   ├── matugen/       # color pipeline (templates)
│   ├── kitty/  mako/  fuzzel/  swaylock/  kanshi/
│   ├── cava/  btop/  fastfetch/
│   ├── Thunar/        # custom actions
│   ├── gtk-3.0/       # theme, icons, cursor
│   └── xfce4/         # helpers.rc
├── .local/
│   ├── bin/           # theming, OSD, wallpaper scripts
│   │   └── theme-modules/   # NN-*.sh, run in order after matugen
│   └── share/themes/  # RPRice GTK3 theme
├── .zshrc
├── .p10k.zsh
└── install.sh
```
