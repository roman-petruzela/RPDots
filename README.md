# RPRice — Arch dotfiles

Niri rice for Arch / CachyOS. Glassmorphism, Material You colors generated from the wallpaper.

## Stack

| | |
|---|---|
| Compositor | [niri](https://github.com/YaLTeR/niri) |
| Bar | [waybar](https://github.com/Alexays/Waybar) |
| Dashboard / OSD / bar flyouts | [quickshell](https://quickshell.outfoxxed.me/) |
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

### Black-and-white wallpapers

A monochrome wallpaper has no hue to derive anything from, and matugen's
quantizer then seeds the scheme from a near-black pixel whose channels differ by
a unit or two of compression noise — `saturn-monochrome.mp4` seeds `#040206`,
which is hue 270 at 2.4 % value, and Material You expands that into a full purple
palette. `apply-wallpaper-theme.sh` measures how much of the image actually
carries colour (pixels with `S ≥ 0.15` and `V ≥ 0.12`) and switches matugen to
`scheme-monochrome` below 2 %. Measured over the collection the two groups are
far apart: monochrome wallpapers land at 0.00 %, the darkest still-colourful one
at 5.19 %.

`scheme-monochrome` returns true greys, which the pinned `set_saturation: 30`
would repaint red-brown (a grey resolves to hue 0). matugen has no conditionals,
so a grey copy of every template containing `set_saturation` is generated into
`~/.cache/niri-rice/templates-mono/` along with a rewritten `config.toml`. The
templates in `.config/matugen/templates/` stay the single source of truth.

It also flips `primary_container` from a dark tone to a light one (`#d4d4d4`
instead of `#583a6f`). Templates that pin lightness do not care; `kitty-theme.conf`
uses it raw as a background, which is why the postprocess targets an absolute
value instead of halving whatever it finds.

## Tuning

| What | Where | Now |
|---|---|---|
| **Spotify opacity** | `.config/niri/config.kdl` → `window-rule` matching `spotify` → `opacity` | `0.75` |
| Terminal opacity | `.config/kitty/kitty.conf` → `background_opacity` | `0.75` |
| GTK / Thunar alphas | `.local/share/themes/RPRice/gtk-3.0/widgets.css` (top of file) | `rp_window` 0.55, `rp_view` 0.46 |
| Zed alphas | `.config/matugen/templates/zed-theme.json` → `set_alpha` | 0.55 / 0.46 |
| Surface tones | `templates/gtk3-dark.css`, `zed-theme.json`, `spicetify-user.css` | `set_lightness` / `set_saturation` |
| kitty background | `KITTY_BG_VALUE` in `.local/bin/kitty-theme-postprocess.sh` | `0.23` HSV value |
| kitty ANSI legibility floor | `KITTY_MIN_CONTRAST`, same script | `2.5` : 1 vs background |
| Monochrome cutoff | `THEME_MONO_THRESHOLD` (`THEME_MONO_MODE=on\|off\|auto` forces it) | `2.0` % |

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

## Audio

One output for everything, switchable from the bar. Three parts:

**WirePlumber** (`.config/wireplumber/wireplumber.conf.d/51-rp-audio.conf`) sets
`node.stream.restore-target = false` and `linking.follow-default-target = true`:
apps never remember which device they last played on, and running streams move
along when the default output changes. Streams that request a target *themselves*
(OBS monitoring) are unaffected — this only governs streams that asked for
nothing.

**`rp-audio`** is the single entry point for volume (`switch`, `cycle`, `volume`,
`mute`, `unpin`, `sync`, `list`, `daemon`). It always writes volume and mute to
**every** sink, so switching outputs is never audible as a jump.
`niri-rice-audio-sync.service` runs `rp-audio daemon`, which watches
`pactl subscribe` and mirrors any volume change — including ones made in
pavucontrol — onto the other outputs, and frees newly appeared streams so they
follow the default.

`unpin` clears a stream's explicit target via `pw-metadata … target.object -1`.
Note that `pactl move-sink-input` does the opposite: it *pins* the stream, which
is why `qs-cycle-sink.sh` no longer uses it.

Streams listed in `.config/rp-audio/blacklist.conf` (substring match against
`application.process.binary` / `application.name` / `node.name`) are never
touched. Capture streams are never touched either, so screen sharing with audio
in Vesktop and capturing in OBS are unaffected by switching. **Caveat:** if OBS
captures "Monitor of \<a specific card\>" rather than the default, switching the
output moves the audio out from under it. Set OBS to the default device.

**AudioSwitcher.qml** is the Windows-style flyout under the bar (volume icon,
`Mod+Shift+O`, or `qs ipc call audio toggle`). It talks to
`Quickshell.Services.Pipewire` directly rather than shelling out.

An IpcHandler function must **not** be named `show` — it collides with the
`qs ipc show` subcommand, and the call silently prints the signature instead of
running. `qs ipc call` in quickshell 0.3.0 also cannot pass arguments at all,
so the OSD reads its own value (PipeWire for volume, `brightnessctl` for
brightness) instead of receiving one.

## Bar flyouts

Clicking a waybar module opens a quickshell card under the bar. `Flyout.qml` is
the shared shell: card chrome, slide-in, click-outside/Esc to dismiss, and the
jump to whichever monitor niri has focused. Content goes in as plain children —
the default property is the inner Column. Clicking inside never dismisses, so
you can switch several times in a row.

`FocusedOutput.qml` is the bit that asks niri which output is focused, assigns it
to the window and only *then* makes it visible — set the screen after showing and
the window visibly jumps to another monitor. The dashboard uses it too, and
covers the full screen (not just its 380 px panel) so a click anywhere outside
closes it.

| Module | Flyout | IPC |
|---|---|---|
| Volume | `AudioSwitcher.qml` | `qs ipc call audio toggle` |
| Battery | `PowerSwitcher.qml` | `qs ipc call power toggle` |
| Network | `NetworkSwitcher.qml` | `qs ipc call network toggle` |

Only one is open at a time — they share the same spot, so `shell.qml`'s
`openFlyout()` hides the others.

`PowerSwitcher` drives `rp-power` and parses `rp-power status`, whose labels are
Czech; the window translates the values it displays. `NetworkSwitcher` gets
everything from **`rp-net`** (`status` as JSON, plus `wifi`, `connect`,
`disconnect`, `rescan`), keeping nmcli parsing out of QML. A Wi-Fi password is
handed to `nmcli --ask` over **stdin**, never in argv where any local process
could read it off `/proc`; that costs a retry loop on a wrong password, hence
the `timeout`. Note that `nmcli -t` escapes colons inside SSIDs, and `tr` has no
`\xNN` escape — `tr '\x01'` would mangle every `x`, `0` and `1`.

The GPU module is `waybar-gpu.sh`: dGPU load in the bar, both cards in the
tooltip. It only runs `nvidia-smi` when the dGPU is awake — polling it every
3 s would otherwise keep the card from ever suspending in battery mode, the same
reason `rp-power status` checks `runtime_status` first.

## Dashboard

**Now Playing** talks to `Quickshell.Services.Mpris`. Two things it is easy to
get wrong: the properties are `position` and `length` (**seconds**, already
converted from the DBus microseconds) — there is no `trackPosition` or
`trackLength`, and reading names that do not exist silently yields 0, which looks
exactly like a stuck progress bar. And `position` does not tick on its own: a
`Timer` has to call `player.positionChanged()` while playing.

`playerctld` also sits on the bus as a proxy alongside the real player, and it
**keeps reporting the last track after that player exits** — the widget looked
alive, the bar was even scrubbable, but every button went nowhere. So the proxy
is filtered out entirely, not just deprioritised: no real player means no widget.

Not every player fills in the metadata. Firefox publishes no `mpris:length`
(`lengthSupported` is false) and quickshell then returns the *position* as the
length, which pins the progress ratio at 1.0 — so with no known length the bar
stays empty and dimmed and the duration reads "live". It is *not* hidden:
removing it shifts everything below and reads as the bar randomly vanishing. The
last known length is also kept until the track changes, so a momentary gap from
the player cannot blank the bar either. Firefox also publishes no
`mpris:artUrl`, so for a YouTube tab the thumbnail is derived from the video id
in `xesam:url` instead.

Nerd Font glyphs in QML are private-use codepoints that do not survive every
edit — the media buttons silently ended up as empty strings once. The ones in
`MediaWidget` are written as `\uf04b`-style escapes for that reason.

**Quick actions** are Lock / Restart / Shut down. Restart and shut down arm an
inline confirmation first (clicking the button again cancels); lock fires
straight away, since it costs nothing to undo. Shut down is `systemctl poweroff`
— it used to be `niri msg action quit`, which only ended the session.

## Power modes

`rp-power` switches CPU / dGPU / animation profiles in one step. This laptop is
Optimus (AMD Cezanne iGPU + RTX 3050 Mobile) and **both displays hang off the
iGPU** — the dGPU has no outputs and is render-offload only.

| | `battery` | `balanced` | `gaming` | `turbo` |
|---|---|---|---|---|
| ACPI platform profile | low-power | balanced | performance | performance |
| CPU governor | TLP | TLP | performance | performance |
| dGPU power limit | 40 W | 60 W | 85 W | 85 W |
| dGPU clock floor | — | — | 800 MHz | 800 MHz |
| video wallpaper | on | on | **suspended** | **suspended** |
| niri animations | on | on | on | **off** |

```bash
rp-power gaming      # or battery / balanced / turbo
rp-power status
```

`gaming` and `turbo` are hardware-identical; `turbo` additionally kills desktop
animations. The clock floor is **not** an overclock — voltage stays on the stock
V/F curve. Its purpose is to stop the dGPU collapsing to 210 MHz mid-frame,
which wrecks frametime consistency under PRIME offload.

**CPU is deliberately left to TLP** except in `gaming`/`turbo`. TLP is installed
and already switches on AC/battery events; two governor managers would fight.

**Video wallpaper** is suspended in `gaming`/`turbo` via
`wallpaper-video-ctl.sh inhibit`, which drops a flag at
`~/.cache/niri-rice/video-inhibit` and kills mpvpaper. The static awww layer
stays up, so the desktop just freezes on the video's first frame instead of
going blank. The flag is honoured inside `wallpaper-video-ctl.sh` rather than by
the caller — otherwise the healthcheck timer (`OnUnitActiveSec=2min`) would call
`ensure` and resurrect the video mid-game. Reason for suspending it at all: the
video decodes and composites on the **iGPU**, which is the same GPU that takes
every game frame off the dGPU, so the two contend for the one path that is
already the bottleneck.

**Animations** live in `.config/niri/power-mode.kdl`, pulled in by `config.kdl`
via `include optional=true`. The file is generated (gitignored, like
`theme-colors.kdl`) — the canonical content is the heredoc in `.local/bin/rp-power`,
and it is materialised on the first `rp-power` run. Every write is checked with
`niri validate` and rolled back on failure, so a bad write cannot take the
desktop down.

The privileged half lives in `.local/share/rp-power/`:

```bash
sudo ~/.local/share/rp-power/install.sh
```

It installs `/usr/local/bin/rp-power-apply`, a NOPASSWD sudoers rule scoped to
that one binary, a udev rule on `ACAD`, and a oneshot unit. Unplugging drops to
`battery` regardless of the selected mode; plugging back in restores the choice
(persisted in `/var/lib/rp-power/mode`).

> The dGPU only reaches 0 W when it runtime-suspends, which needs *nothing*
> holding a context on it — `nvidia-smi` itself wakes it, so the script skips it
> while suspended. niri, Steam and browsers do hold contexts; pinning niri to the
> iGPU with `debug { render-drm-device "/dev/dri/renderD128" }` is the lever if
> battery life matters more than whatever niri gains from the dGPU.

## Keybindings

| | |
|---|---|
| `Mod+T` | Terminal |
| `Mod+D` | Launcher |
| `Mod+E` | Files (yazi) |
| `Mod+Q` | Close window |
| `Mod+Shift+W` | Pick wallpaper + apply theme |
| `Mod+Shift+D` | Dashboard |
| `Mod+Shift+O` | Audio output switcher |
| `Mod+Ctrl+O` | Next audio output |
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
│   ├── quickshell/    # dashboard + OSD + audio switcher
│   ├── wireplumber/   # one output for all apps
│   ├── rp-audio/      # blacklist for the output switcher
│   ├── systemd/user/  # quickshell, audio sync, waybar/theme/healthcheck units
│   ├── matugen/       # color pipeline (templates)
│   ├── kitty/  mako/  fuzzel/  swaylock/  kanshi/
│   ├── cava/  btop/  fastfetch/
│   ├── Thunar/        # custom actions
│   ├── gtk-3.0/       # theme, icons, cursor
│   └── xfce4/         # helpers.rc
├── .local/
│   ├── bin/           # theming, OSD, wallpaper scripts, rp-power
│   │   └── theme-modules/   # NN-*.sh, run in order after matugen
│   └── share/
│       ├── themes/    # RPRice GTK3 theme
│       └── rp-power/  # root half of power modes (install.sh + helper)
├── .zshrc
├── .p10k.zsh
└── install.sh
```
