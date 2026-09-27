#!/usr/bin/env bash
# Instalace rice: balíky, nasazení configů do $HOME, první vygenerování tématu
# a volitelně systémové (sudo) části. Spouštěj z běžícího niri, ať se téma
# a služby rovnou načtou:
#
#   ./install.sh
set -euo pipefail

# Pod rootem by configy skončily v /root a paru pod rootem nepoběží — sudo si
# skript řekne sám tam, kde je potřeba
if [[ $EUID -eq 0 ]]; then
    echo "Run install.sh as your normal user, not with sudo — it asks for the password once at the start." >&2
    exit 1
fi

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"

# Pořadí nehraje roli — co není v repozitářích (na čistém Archu awww, matugen,
# mpvpaper, swaylock-effects, quickshell…), se samo nainstaluje přes paru.
PKGS=(
    # compositor, bar, shell
    niri
    waybar
    quickshell
    qt6-multimedia          # živý náhled video tapet v pickeru
    kitty
    mako
    fuzzel                  # záloha, když quickshell neběží (Mod+D)
    rofi                    # záloha pickeru tapet (rofi 2.0 umí Wayland)
    swaylock-effects
    swayidle
    kanshi

    # tapety a téma
    awww
    mpvpaper
    mpv
    matugen
    imagemagick
    ffmpeg
    python

    # utility, které volají skripty a quickshell
    jq
    socat                   # rp-shell → quickshell socket
    wl-clipboard
    cliphist                # historie schránky (Mod+Ctrl+V)
    grim
    slurp
    tesseract
    tesseract-data-ces      # OCR: tesseract -l ces+eng
    tesseract-data-eng
    libnotify
    zenity
    playerctl
    brightnessctl
    wireplumber
    libpulse
    pavucontrol
    networkmanager
    nm-connection-editor
    gamemode
    rsync
    stow
    git

    # terminál a CLI
    zsh
    eza
    zoxide
    atuin
    fnm
    yazi
    neovim
    cava
    btop
    fastfetch

    # vzhled
    ttf-jetbrains-mono-nerd
    papirus-icon-theme
    bibata-cursor-theme-bin
    nwg-look
    qt5ct
    qt6ct

    # soubory
    thunar
    thunar-archive-plugin
    thunar-volman
    xfce4-settings
    gvfs
    gvfs-smb
    gvfs-afc
    tumbler
    ffmpegthumbnailer
    poppler-glib
    libgsf
)

# Soubory z repa, které do $HOME nepatří
NOT_DEPLOYED=(.gitignore .stow-local-ignore README.md install.sh CLAUDE.md)

# Heslo pro sudo jednou na začátku, pak ho smyčka na pozadí drží platné
# (výchozí timeout sudo je 5 minut, build z AUR trvá déle) — pacman, makepkg
# i paru se už neptají. Smyčka skončí se skriptem.
need_sudo() {
    [[ -n "${SUDO_KEEPALIVE:-}" ]] && return 0
    echo "Some steps need root — enter your password once, it's kept for the whole run."
    sudo -v || { echo "sudo failed." >&2; exit 1; }
    while kill -0 $$ 2>/dev/null; do sudo -n -v 2>/dev/null || true; sleep 50; done &
    SUDO_KEEPALIVE=$!
    trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT
}

ask() {
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" == [yYaA]* ]]
}

in_session() {
    [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v niri >/dev/null && niri msg version >/dev/null 2>&1
}

# ------------------------------------------------------------------ balíky

install_packages() {
    echo "== Packages"
    # Nejdřív čerstvá databáze, ať se balíky správně rozdělí na repo/AUR…
    sudo pacman -Sy
    local pkg repo=() aur=()
    for pkg in "${PKGS[@]}"; do
        pacman -Qi "$pkg" &>/dev/null && continue
        if pacman -Si "$pkg" &>/dev/null; then repo+=("$pkg"); else aur+=("$pkg"); fi
    done

    if [[ ${#repo[@]} -gt 0 ]]; then
        echo "From the repositories: ${repo[*]}"
        # …a pak -Su: instalovat nové balíky proti čerstvé databázi bez upgradu
        # zbytku systému je částečný upgrade, který Arch nepodporuje (např. nová
        # libbluray rozbije nainstalovaný ffmpeg: "breaks dependency libbluray.so")
        echo "(this also upgrades the rest of the system — Arch doesn't support partial upgrades)"
        sudo pacman -Su --needed "${repo[@]}"
    fi
    if [[ ${#aur[@]} -gt 0 ]]; then
        command -v paru &>/dev/null || install_paru
        if command -v paru &>/dev/null; then
            echo "From the AUR: ${aur[*]}"
            paru -S --needed "${aur[@]}"
        else
            echo "Not in the repositories and no paru to get them from the AUR: ${aur[*]}" >&2
        fi
    fi
    [[ ${#repo[@]} -eq 0 && ${#aur[@]} -eq 0 ]] && echo "Everything is installed."
    return 0
}

# Na čistém Archu paru není. paru-bin z AUR (předkompilovaný, bez stahování
# celého Rust toolchainu) přes makepkg.
install_paru() {
    echo "Some packages are only in the AUR, and paru (the AUR helper) is not installed."
    ask "Install paru from the AUR now?" || return 0
    sudo pacman -S --needed base-devel git
    local tmp; tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" \
        && (cd "$tmp/paru-bin" && makepkg -si --noconfirm); then
        echo "paru installed."
    else
        echo "!! Installing paru failed — AUR packages are skipped." >&2
    fi
    rm -rf "$tmp"
}

# ----------------------------------------------------------------- configy

# Soubory, které repo sleduje (i nové, ještě necommitnuté), bez ignorovaných —
# vygenerované věci (Colors.js, mako/config…) tak nikdy nepřepíše.
#
# Bez .git (repo stažené z GitHubu jako ZIP) se berou všechny soubory — ZIP
# obsahuje jen to, co repo sleduje, takže vygenerované věci v něm nejsou.
repo_files() {
    local skip f
    {
        if git -C "$DOTFILES" rev-parse --is-inside-work-tree &>/dev/null; then
            git -C "$DOTFILES" ls-files --cached --others --exclude-standard
        else
            (cd "$DOTFILES" && find . -type f -not -path './.git/*' | sed 's|^\./||')
        fi
    } | while IFS= read -r f; do
        for skip in "${NOT_DEPLOYED[@]}"; do [[ "$f" == "$skip" ]] && continue 2; done
        [[ -f "$DOTFILES/$f" ]] && printf '%s\n' "$f"
    done
}

# Kopie do $HOME (tak je rice nasazený i teď — žádné symlinky). Soubor, který
# v $HOME existuje a liší se, se před přepsáním zálohuje, takže ruční úpravy
# živé kopie se neztratí. S dry=1 jen vypíše, co by se změnilo.
copy_configs() {
    local dry="${1:-0}" f src dst backup="" changed=0 new=0
    [[ "$dry" == 1 ]] || backup="$STATE_DIR/deploy-backup/$(date +%Y%m%d-%H%M%S)"
    echo "== Configs → $HOME${backup:+ (changed files backed up to $backup)}"

    while IFS= read -r f; do
        src="$DOTFILES/$f"
        dst="$HOME/$f"
        if [[ -L "$dst" ]]; then
            # Stow symlink do repa — už je aktuální
            [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]] && continue
        elif [[ -f "$dst" ]]; then
            cmp -s "$src" "$dst" && continue
            changed=$((changed + 1))
            echo "  changed  $f"
        else
            new=$((new + 1))
            echo "  new      $f"
        fi
        [[ "$dry" == 1 ]] && continue

        if [[ -e "$dst" || -L "$dst" ]]; then
            mkdir -p "$backup/$(dirname "$f")"
            cp -P "$dst" "$backup/$f"
            rm -f "$dst"
        fi
        mkdir -p "$(dirname "$dst")"
        cp -p "$src" "$dst"
    done < <(repo_files)

    echo "$new new, $changed changed."
    if [[ "$dry" != 1 && $changed -eq 0 && -n "$backup" ]]; then rmdir -p "$backup" 2>/dev/null || true; fi
    if [[ "$dry" != 1 ]] && command -v niri >/dev/null; then
        niri validate -c "$HOME/.config/niri/config.kdl" >/dev/null 2>&1 \
            || echo "!! niri validate failed for ~/.config/niri/config.kdl" >&2
    fi
}

stow_configs() {
    echo "== Symlinking configs with stow"
    stow --dir="$DOTFILES" --target="$HOME" --restow .
}

# ------------------------------------------------------------ po nasazení

post_deploy() {
    echo "== Session setup"
    systemctl --user daemon-reload

    # Yazi pluginy (.config/yazi/package.toml, samotné pluginy nejsou v repu)
    command -v ya >/dev/null && ya pkg install >/dev/null 2>&1 || true

    if ! in_session; then
        echo "Not inside a running niri session — log into niri, then run"
        echo "  ~/.local/bin/apply-wallpaper-theme.sh ~/Pictures/Wallpapers/<some wallpaper>"
        echo "to generate the colours (quickshell won't start without Colors.js)."
        return 0
    fi

    # Barvy (Colors.js, mako, waybar…) generuje až téma. Na čistém stroji zatím
    # nejsou a quickshell by se bez Colors.js vůbec nenačetl.
    if [[ ! -f "$HOME/.config/quickshell/Colors.js" ]]; then
        local wall
        wall="$(find "$HOME/Pictures/Wallpapers" "$HOME/Pictures" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            -print -quit 2>/dev/null || true)"
        if [[ -n "$wall" ]]; then
            echo "Generating the theme from $wall"
            "$HOME/.local/bin/apply-wallpaper-theme.sh" "$wall" || true
        else
            echo "No wallpaper found — put one in ~/Pictures/Wallpapers and press Mod+Shift+W."
        fi
    fi

    # Služby rice spouští niri při přihlášení (start-rice-services.sh — ten tu
    # znovu nepouštím, zdvojil by procesy). Běžící se jen restartují, ať si
    # načtou nové soubory; historie schránky je nová, tak se rovnou zapne.
    systemctl --user try-restart niri-rice-quickshell.service niri-rice-audio-sync.service \
        2>/dev/null || true
    systemctl --user start niri-rice-cliphist.service 2>/dev/null || true
    pkill -USR2 -x waybar 2>/dev/null || true
    command -v makoctl >/dev/null && makoctl reload 2>/dev/null || true
    echo "Done."
}

# ------------------------------------------------------- systémové části

system_setup() {
    echo "== System integration"
    local share="$HOME/.local/share"

    if ask "Power modes (rp-power: sudoers rule, udev rule on AC, systemd units)?"; then
        sudo "$share/rp-power/install.sh"
    fi
    if ask "Mirror the theme and wallpaper to the login screen (rp-lightdm-sync)?"; then
        sudo "$share/rp-lightdm-sync/install.sh"
    fi
    echo
    echo "The quickshell login screen replaces LightDM with greetd (back with --revert)."
    echo "Preview it first: $share/rp-greeter/preview.sh"
    if ask "Switch the login screen to rp-greeter now?"; then
        sudo "$share/rp-greeter/install.sh"
    fi
}

# ------------------------------------------------------------------- menu

echo "=== niri rice install ==="
echo "Dotfiles: $DOTFILES"
echo

PS3="Choose: "
select action in \
    "Everything (packages, configs, session setup)" \
    "Install packages" \
    "Copy configs to \$HOME" \
    "Show what copying would change" \
    "Symlink configs with stow instead of copying" \
    "System integration (sudo helpers, login screen)" \
    "Cancel"; do
    case "$REPLY" in
        1) need_sudo; install_packages; copy_configs; post_deploy
           echo; ask "Also run the system integration steps?" && system_setup
           break ;;
        2) need_sudo; install_packages; break ;;
        3) copy_configs; post_deploy; break ;;
        4) copy_configs 1; break ;;
        5) stow_configs; post_deploy; break ;;
        6) need_sudo; system_setup; break ;;
        7) exit 0 ;;
        *) echo "Pick a number from the list." ;;
    esac
done
