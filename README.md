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
| Terminal opacity | `.config/kitty/kitty.conf` → `background_opacity` | `0.45` (lower than the rest since niri blurs behind it) |
| GTK / Thunar alphas | `.local/share/themes/RPRice/gtk-3.0/widgets.css` (top of file) | `rp_window` 0.55, `rp_view` 0.46 |
| Zed alphas | `.config/matugen/templates/zed-theme.json` → `set_alpha` | chrome 0.78, editor/terminal 0.85 |
| Surface tones | `templates/gtk3-dark.css`, `zed-theme.json`, `spicetify-user.css` | `set_lightness` / `set_saturation` |
| kitty background | `KITTY_BG_VALUE` / `KITTY_BG_MAX_SAT` in `.local/bin/kitty-theme-postprocess.sh` | `0.23` HSV value, saturation ≤ `0.35` |
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

**LightDM greeter** (login screen) mirrors the RPRice GTK3 theme and the
current wallpaper. `lightdm-gtk-greeter` runs as its own user and can't read
`/home/roman` (chmod 700), so `theme-modules/84-lightdm.sh` shells out to a
privileged helper that copies both into `/usr/share/themes/` and
`/usr/share/backgrounds/` and points `lightdm-gtk-greeter.conf` at them. Same
pattern as [power modes](#power-modes) below: install once with

```bash
sudo ~/.local/share/rp-lightdm-sync/install.sh
```

which drops `/usr/local/bin/rp-lightdm-sync-apply` and a NOPASSWD sudoers rule
scoped to that one binary. Until it's installed, `requires=` in
`.config/niri-rice/modules.conf` makes the module a silent no-op. The greeter
itself isn't restarted (that would kill the running graphical session) — the
new theme just takes effect next time it's shown.

**rp-greeter** replaces lightdm-gtk-greeter with a login screen in quickshell,
styled like the wallpaper picker: the blurred wallpaper, a clock at the top, a
single password field in the middle (no avatar, no user list, just the one
user) with a CZ/US layout chip, and suspend/restart/shut down at the bottom.
The stack is greetd → a bare niri (`.local/share/rp-greeter/niri.kdl`: same
keyboard layouts and outputs as the session, no binds) → `qs -p
/usr/share/rp-greeter/greeter`. On login `Greetd.launch(..., quit=true)` ends
quickshell, niri quits after it, and greetd starts `niri-session`. The password
lives in the ShellRoot rather than a TextInput because there is a window on
every monitor and typing works on any of them. The helper above also copies
`Colors.js` to the greeter whenever the theme changes.

```bash
~/.local/share/rp-greeter/preview.sh                 # try it in the session (password "test")
sudo ~/.local/share/rp-greeter/install.sh            # install greetd, switch from LightDM
sudo ~/.local/share/rp-greeter/install.sh --revert   # back to LightDM
```

`install.sh` also adds `pam_gnome_keyring` to `/etc/pam.d/greetd`. LightDM's
PAM stack unlocked the keyring at login and greetd's doesn't, so secrets would
otherwise stop unlocking on their own.

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
| Volume | `AudioSwitcher.qml` | `rp-shell audio toggle` |
| Battery | `PowerSwitcher.qml` | `rp-shell power toggle` |
| Network | `NetworkSwitcher.qml` | `rp-shell network toggle` |

**`rp-shell <target> <function>`** is how keybinds, waybar and the OSD scripts
talk to quickshell. It writes one line to a `SocketServer` in `shell.qml`
(`$XDG_RUNTIME_DIR/rp-shell.sock`) via socat: ~7 ms, against ~40 ms for
`qs ipc call`, which boots a whole Qt client per call — that was the noticeable
lag on volume keys and flyouts. The server closes the connection after reading
(if the client did, quickshell would log a `PeerClosedError` per call). Without
the socket it falls back to `qs ipc call`, so the `IpcHandler`s stay; a new
target needs a line in `shell.qml`'s `dispatch()` too.

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

## Wallpaper picker

`Mod+Shift+W` runs `rp-shell wallpaper toggle` and only falls back to the old
rofi list (`pick-wallpaper.sh --rofi`) when quickshell isn't running. `WallpaperPicker.qml` is a full-screen
3D coverflow: side cards are `Rotation`s around the Y axis (Qt Quick projects
those with real perspective), placed on a `PathView` path that is stretched in
the middle and compressed at the edges so the neighbours stack like book pages.
Enter hands the path to `apply-wallpaper-theme.sh` — never matugen directly —
with `AWWW_TRANSITION_TYPE=none`: the card zooming to full screen *is* the
transition, and a wave from awww afterwards read as a second, redundant one.
(`01-wallpaper-transition.sh` forces `step=255` for `none`, otherwise its explicit
`--transition-step 10` would slow the alias back down.) The zoomed card stays up
until `wallpaper-video-ctl.sh` writes `~/.cache/niri-rice/wallpaper-shown` —
awww has swapped the image *and* any old mpvpaper is gone — and then dissolves
in 160 ms, so the switch looks instant even when a video has to be killed first.
A 2.5 s timeout covers a missing signal. `stop_video` now polls every 50 ms
(was 250 ms) before escalating to SIGKILL, since that wait now delays the reveal.

The model is only rebuilt when the list of paths/thumbnails changes, so cards and
their decoded thumbnails survive closing and the picker opens fully drawn.

The picker has no backdrop of its own. Its overlay (`rp-wallpaper-picker`) gets
niri blur with `xray false`, so the windows underneath stay visible, blurred.
The focused wallpaper is previewed *behind* them by `WallpaperPreview.qml`: one
Bottom-layer surface per monitor (above awww and mpvpaper in the Background layer),
full resolution for images and the 960 px thumbnail for videos. After Enter the card
zooms out and fades, the overlay unmaps, and the preview stays until the
wallpaper-shown signal arrives.

### Blur and video wallpapers

niri's default blur is **xray**: a window blurs the *backdrop*, meaning the layers
with `place-within-backdrop`, not what is really behind it. That is cheap because a
static wallpaper is blurred once and reused. mpvpaper used to run in the Bottom
layer, and `place-within-backdrop` only applies to the Background layer, so every
blurred window (kitty, fuzzel, mako) showed awww's frozen first frame while the
video played above it. mpvpaper now runs in the Background layer with its own
`place-within-backdrop` rule, so the blur follows the video, at the cost of one
re-blur per video frame (`battery`/`gaming` stop the video anyway). Within one layer
niri draws the most recently mapped surface on top. That is why the healthcheck
runs `sync` (restarting mpvpaper) instead of `ensure` after it had to restart
awww-daemon: otherwise the fresh awww surface would cover the video.

The list comes from `pick-wallpaper.sh --list` (path, thumbnail, kind, current).
The 960×540 thumbnails are named `large-v1-<mtime>_<size>-<basename>.jpg`
instead of the md5 key the rofi thumbnails use: the whole directory then needs a
single `stat`, and `--list` takes ~20 ms instead of 1.7 s with one `md5sum`
per file. Missing thumbnails are generated by the same serial, locked,
low-priority dispatcher as before; cards retry loading until they show up.
The focused video card plays a muted preview after it settles (450 ms), unless
`rp-power` has set the video-inhibit flag. It lives in
`WallpaperVideoPreview.qml` behind a `Loader`, so a missing QtMultimedia breaks
only the preview, not the picker.

## Workspace and window switchers

`Mod+Tab` is Alt+Tab for workspaces (`WorkspaceSwitcher.qml`): hold Mod, Tab
cycles, releasing Mod switches. The Tab presses never reach quickshell. niri
handles the bind and runs `rp-shell workspaces next`, so the window only sees the
Mod release. If Mod is released before the window gets keyboard focus (an
extremely fast tap), the switcher stays open; Enter switches and Esc closes.
Cards keep a fixed order, the focused monitor first and then by workspace
number, so each workspace always sits in the same spot. The selection starts on
the most recently used other workspace (newest `focus_timestamp` among its
windows), so a quick Mod+Tab still jumps back and forth. A dot marks the current
workspace, and the monitor name appears only on each monitor's first card. Empty
workspaces are left out.

The card is not a screenshot. niri reports no per-window position on screen
(`tile_pos_in_workspace_view` is `null` for tiled windows), and grabbing each
workspace with `grim` costs ~100 ms per shot, too much to run during games. Each
card is a minimap instead: the columns of the scrolling layout in their real
width ratio (`pos_in_scrolling_layout`, `tile_size`), with app icons, over the
960 px wallpaper copy matugen already gets (`wal-matugen.png`).

Workspace and window data come from `NiriState.qml`, one long-running
`niri msg --json event-stream` that keeps the state live. Opening the switcher
therefore needs no IPC round-trip. The snapshot is taken on open, so the order
doesn't reshuffle while you cycle.

`Alt+Tab` (`WindowSwitcher.qml`) works the same way for windows. niri's
built-in `recent-windows` switcher is turned `off` because it has live previews
but can hardly be restyled, and its default binds would also take Mod+Tab.
quickshell can't get live window previews on niri (there is no per-window
screencopy), so each window card shows the app, the title, the workspace and a
small minimap with the window highlighted. ``Alt+` `` limits the list to the
focused app. The cards form a grid of at most 7×3; with more windows the grid
scrolls a row at a time to keep the selection visible, with a scrollbar and a
counter (↑/↓ or the wheel move by a row). Cards stay at full size rather than
shrinking to fit, because titles become unreadable below ~200 px. The shared pieces (`minimap()`, app icons, output labels) live in
`NiriState.qml` and `Minimap.qml`.

### Open/close animation

The launcher and both switchers fade and scale in from 94 % and shrink slightly
as they fade out, macOS-style (`PopAnim.qml`, ~220 ms `OutQuint` in, ~140 ms
out). niri has no open/close animation for layer surfaces, so it is done inside
the surface: `hide()` starts the fade-out and only the end of the animation sets
`visible = false`. Keyboard focus is dropped as soon as the fade-out starts
(`pop.shown`), so keys already go to the window you switched to.

The blur is what makes this fiddly. A `blur true` layer-rule blurs the whole
surface at full size from the first frame, leaving a sharp-edged blurred
rectangle around the small transparent card. So these windows request the blur
themselves through ext-background-effect (`BackgroundEffect.blurRegion`) with a
region that tracks the scaled card and only switches on past ~30 % opacity. The
launcher's namespace moved from fuzzel's `launcher` to `rp-launcher` for the
same reason; fuzzel and the clipboard history keep the rule. `HoverSelect`
rounds the scene position to whole pixels, because while the card is scaling,
mapping through `scale` gives fractional jitter that looked like the mouse
moving and made the selection jump under a still cursor.

## Launcher and session menu

`Mod+D` opens `Launcher.qml` and `Mod+Shift+E` opens `SessionMenu.qml`. The
session menu is a full-screen `rp-overlay` layer that blurs the windows
underneath (`xray false`), like the wallpaper picker; the launcher is a small
centered card (see the open/close animation below). The launcher lists recently launched apps first when
the query is empty (`~/.cache/niri-rice/launcher-recent.json`), ranks matches by
name, word start, generic name, keywords, comment and in-order letters, and turns
a sum like `12*7+3` into a result that Enter copies. The results refresh when
`DesktopEntries` finishes loading, which is asynchronous and would otherwise
leave the first open after a quickshell start empty. `shell.qml` sets
`//@ pragma IconTheme Papirus-Dark`. Without it quickshell only searches
hicolor and draws generic names like `utilities-system-monitor` as a
checkerboard. Pragmas are read at startup, so changing it needs
`systemctl --user restart niri-rice-quickshell`.

Mouse hover in all keyboard-driven lists (launcher, clipboard, session menu, both
switchers) goes through `HoverSelect.qml`, which moves the selection only when
the cursor itself moves. A plain `onEntered` also fires when the list scrolls
under a still cursor during fast arrow-key scrolling, or when a switcher opens
under it, and the selection then jumped to whatever was under the mouse.

## Clipboard history

`niri-rice-cliphist.service` runs `wl-paste --watch cliphist store`, so every
selection (text or image) lands in cliphist. `Mod+Ctrl+V` opens
`ClipboardHistory.qml`, the same fuzzel-like box as the launcher (Mod+Shift+V
was already taken by the floating/tiling focus switch). Typing filters, Enter
decodes the entry back into the clipboard, and Shift+Delete removes it. Pasting
stays a manual Ctrl+V, because auto-paste would need `wtype`. Image previews are
decoded lazily, only for rows that get drawn, into `$XDG_RUNTIME_DIR/rp-clip`
(tmpfs), and that directory is wiped on every open. The unit has
`ConditionPathExists=/usr/bin/cliphist`, so it stays quiet until cliphist is
installed.

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

## Settings window

`Mod+S` (`rp-shell settings toggle`, or `rp-shell settings <page>` to open a
page directly: `appearance`, `windows`, `keyboard`, `mouse`, `theme`,
`notifications`, `power`, `tools`) opens `Settings.qml`. It is also in the
launcher as **Settings** (`.local/share/applications/rp-settings.desktop`). It is
a normal floating toplevel rather than a layer, so it can be moved and niri
animates it (window-rule on the title `RPRice Settings`).

About 65 options across the pages: gaps, corner radius, focus ring, inactive
opacity, shadows, blur, animation speed; column width and display, centering,
overview zoom, hot corner, focus behaviour; keyboard layouts, switch key, Caps
Lock, compose, repeat; touchpad and mouse (tap, drag, speed, profile, scroll,
click method, left-handed); cursor theme and size, hiding; matugen scheme and
contrast, monochrome, wallpaper transition, terminal opacity and font, Spotify
opacity, theme modules; notifications (do not disturb, position, timeout),
idle lock and screen off; power modes; system tools. `Ctrl+F` searches all of
them. A dot next to a label marks a changed value, and clicking it resets it.

The window only draws. **`rp-settings`** owns the data: the schema (type,
default, range or options) is one table in the script, `dump` hands it all to
QML as JSON in one `jq` pass, and `set` validates and applies. In `Settings.qml`
the `pages` list just places keys on pages with a label; the control is picked
from the type (bool → switch, number → slider, enum → segments or a dropdown,
string → text field). A new option is a schema line (plus its output) in
`rp-settings` and one line in `pages`. Only values that differ from the default
are stored, in `~/.config/niri-rice/settings.json`. Outputs:

| Keys | Output | Applied by |
|---|---|---|
| `niri.*`, `input.*`, `cursor.*`, Spotify opacity | `~/.config/niri/settings.kdl` | niri live reload, after `niri validate` (rollback on failure) |
| `cursor.*` | also gsettings, GTK `settings.ini`, `icons/default/index.theme` | new apps |
| `theme.terminal_*` | `~/.config/kitty/rp-settings.conf` (included last in `kitty.conf`) | `kitty @ set-background-opacity/set-font-size` on running terminals |
| `notify.*` | `~/.config/mako/rp-settings` (`include=` in the mako template) | `makoctl reload`, `makoctl mode` for do not disturb |
| `idle.*` | swayidle command line | `rp-settings idle` restarts swayidle (`start-rice-services.sh` starts it the same way) |
| `theme.scheme`, `theme.contrast`, `theme.mono_mode` | read by `apply-wallpaper-theme.sh` | next theme regenerate |
| `wallpaper.*` | read by `theme-modules/01-wallpaper-transition.sh` | next wallpaper change |

`settings.kdl` is included at the very end of `config.kdl`, so it overrides the
layout, blur, overview and cursor there, and the animation speed and on/off from
`power-mode.kdl` (`rp-power` keeps only the curves). It always contains every
managed key, not just the changed ones: an include can switch a flag on but not
off (niri rejects `natural-scroll false`, `tap false`, `numlock false`), so those
flags were moved out of `config.kdl` and `settings.kdl` is their only source.

mako refuses its whole config when an `include=` file is missing, so
`start-rice-services.sh` runs `rp-settings apply` before the theme, and
`theme-modules/40-mako.sh` creates the file if it is gone. Backgrounded
swayidle is started with `9>&-`; otherwise it inherits the `flock` descriptor
and every later `rp-settings` call hangs.

**Regenerate theme** passes the current wallpaper path to
`apply-wallpaper-theme.sh`. Run without an argument, the script sees the same
wallpaper signature and exits without regenerating anything.

The window is created fresh on every open (`LazyLoader`) and dropped on close.
When niri closes it (`Mod+Q`), quickshell destroys the toplevel and emits
`closed`, but the object keeps `visible: true`, so setting `visible = true`
again never reopened it. Changing the theme rewrites `Colors.js`, and quickshell
reloads the whole shell. The open state and page live in `PersistentProperties`
(the wrapping `Scope` needs a `reloadableId` for that), so the window comes back
where it was. `qs ipc call shell reload` is a *hard* reload and drops that state
on purpose.

## Power modes

`rp-power` switches CPU / dGPU / animation profiles in one step. This laptop is
Optimus (AMD Cezanne iGPU + RTX 3050 Mobile) and **both displays hang off the
iGPU** — the dGPU has no outputs and is render-offload only.

| | `battery` | `balanced` | `gaming` |
|---|---|---|---|
| ACPI platform profile | low-power | balanced | performance |
| CPU governor | **powersave** | performance | performance |
| CPU EPP | **power** | performance | performance |
| dGPU power limit | 40 W | 60 W | 85 W |
| dGPU clock floor | — | — | 800 MHz |
| video wallpaper | **suspended** | on | **suspended** |
| niri animations | on | on | on |

```bash
rp-power gaming      # or battery / balanced
rp-power status
```

The clock floor is **not** an overclock — voltage stays on the stock V/F
curve. Its purpose is to stop the dGPU collapsing to 210 MHz mid-frame, which
wrecks frametime consistency under PRIME offload.

**All three modes set CPU governor/EPP explicitly** — `balanced` used to
leave it to TLP, but governor/EPP is global sysfs state that persists across
mode switches until something writes it again: after `battery` or `gaming`,
`balanced` would silently keep whatever the *previous* mode had set
(`powersave`/`power`, or `performance`/`performance`) instead of what TLP
would actually pick, since no AC event fired in between to make TLP re-apply
anything. Explicit beats implicit here: `balanced`/`gaming` both pin
`performance`/`performance` (they differ in ACPI profile, dGPU power limit
and clock lock, not CPU), and `battery` pins `powersave`/`power` for the
"save power now" case.

**Video wallpaper** is suspended in `battery` and `gaming` via
`wallpaper-video-ctl.sh inhibit`, which drops a flag at
`~/.cache/niri-rice/video-inhibit` and kills mpvpaper. The static awww layer
stays up, so the desktop just freezes on the video's first frame instead of
going blank. The flag is honoured inside `wallpaper-video-ctl.sh` rather than by
the caller — otherwise the healthcheck timer (`OnUnitActiveSec=2min`) would call
`ensure` and resurrect the video mid-game/mid-battery. Reason for suspending it
in `gaming`: the video decodes and composites on the **iGPU**, which is the
same GPU that takes every game frame off the dGPU, so the two contend for the
one path that is already the bottleneck. Reason for suspending it in
`battery`: video decode draws noticeably more power than a static image.

Unplugging AC (or the periodic guard timer, see below) only ever touches the
*hardware* knobs through the root helper — it has no session to run
`wallpaper-video-ctl.sh` in. The wallpaper suspend/resume above is applied by
`~/.local/bin/rp-power` itself when you run it manually, and by
`niri-rice-power-sync.path`/`.service` (a `systemd --user` path unit, same
pattern as `niri-rice-theme.path`) when the root side changes
`/var/lib/rp-power/effective` — so unplugging while in `balanced` (video
playing) also suspends the wallpaper, not just an explicit `rp-power battery`.

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
that one binary, a udev rule on `ACAD`, an AC-change oneshot unit, and
`rp-power-gpu-guard.timer` (every 2 min). Unplugging drops to `battery`
regardless of the selected mode; plugging back in restores the choice
(persisted in `/var/lib/rp-power/mode`, mirrored to `/var/lib/rp-power/effective`
for whichever mode is *actually* applied right now — see the wallpaper-sync
note above).

The guard timer exists because `nvidia-smi -pl`/`-lgc` don't survive the dGPU
going through a runtime suspend/resume cycle — the driver resets to its own
default limit on wake, so a battery-mode session that wakes the dGPU
mid-session (a browser tab, a game) would otherwise silently sit at the
driver default (measured: 60-70 W) instead of the intended 40 W cap until the
next AC event. The timer just re-runs the same idempotent `auto` apply; it's
a no-op while the dGPU is suspended, so it never wakes it just to check.

`rp-power-auto.service` intentionally has no `After=tlp.service` — this
system's `tlp.service` is itself `After=multi-user.target`, and combining
that with our own `WantedBy=multi-user.target` created an ordering cycle
systemd broke arbitrarily on every boot (`Found ordering cycle` in the
journal). Dropping the ordering edge fixes the cycle; the two units don't
actually need boot-order coordination, since `battery`'s explicit CPU clamp
above is what makes the mode not depend on TLP having already run.

> The dGPU only reaches 0 W when it runtime-suspends, which needs *nothing*
> holding a context on it — `nvidia-smi` itself wakes it, so the script skips it
> while suspended. niri, Steam and browsers do hold contexts; pinning niri to the
> iGPU with `debug { render-drm-device "/dev/dri/renderD128" }` is the lever if
> battery life matters more than whatever niri gains from the dGPU.

## Keybindings

| | |
|---|---|
| `Mod+T` | Terminal |
| `Mod+D` | Launcher (quickshell; fuzzel if quickshell isn't running) |
| `Mod+Shift+E` | Session menu: lock, suspend, log out, restart, shut down |
| `Mod+Ctrl+V` | Clipboard history (Enter copies, Shift+Delete removes) |
| `Mod+E` | Files (yazi) |
| `Mod+Q` | Close window |
| `Mod+Shift+W` | Pick wallpaper + apply theme (←/→ one, ↑/↓ ten, type to filter) |
| `Alt+Tab` / `Alt+Shift+Tab` | Window switcher (hold Alt, release to switch) |
| ``Alt+` `` | Window switcher limited to the focused app |
| `Mod+Tab` / `Mod+Shift+Tab` | Workspace switcher (hold Mod, release to switch) |
| `Mod+O` | Overview (zoom 0.35) |
| `Mod+Shift+D` | Dashboard |
| `Mod+S` | Settings |
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
│   ├── quickshell/    # dashboard + OSD + flyouts + wallpaper picker
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
