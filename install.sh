#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run install.sh as your normal user, not with sudo — it asks for the password once at the start." >&2
    exit 1
fi

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"

PKGS=(
    niri
    waybar
    quickshell
    qt6-multimedia
    kitty
    mako
    fuzzel
    rofi
    swaylock-effects
    swayidle
    kanshi

    awww
    mpvpaper
    mpv
    matugen
    imagemagick
    ffmpeg
    python

    jq
    socat
    wl-clipboard
    cliphist
    grim
    slurp
    libnotify
    zenity
    playerctl
    brightnessctl
    wireplumber
    libpulse
    pavucontrol
    networkmanager
    nm-connection-editor
    rsync
    stow
    git

    zsh
    eza
    zoxide
    cava

    ttf-jetbrains-mono-nerd
    papirus-icon-theme
    nwg-look
    qt6ct

    thunar
    thunar-archive-plugin
    thunar-volman
    xfce4-settings
    gvfs
    tumbler
    ffmpegthumbnailer
    poppler-glib
    libgsf
)

EXTRAS=(
    tesseract
    tesseract-data-ces
    tesseract-data-eng
    gamemode
    qt5ct
    gvfs-smb
    gvfs-afc
    atuin
    fnm
    yazi
    neovim
    btop
    fastfetch
)

CURSOR_THEME=Bibata-Modern-Ice
CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/$CURSOR_THEME.tar.xz"

NOT_DEPLOYED=(.gitignore .stow-local-ignore README.md install.sh CLAUDE.md .gitconfig)

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

WANT_EXTRAS=0
choose_extras() {
    echo "Optional extras (the rice works without them, ~350 MB):"
    printf '  %s\n' "${EXTRAS[@]}"
    ask "Install the extras too?" && WANT_EXTRAS=1
    return 0
}

install_packages() {
    echo "== Packages"
    local list=("${PKGS[@]}")
    [[ $WANT_EXTRAS == 1 ]] && list+=("${EXTRAS[@]}")
    sudo pacman -Sy
    local pkg repo=() aur=()
    for pkg in "${list[@]}"; do
        pacman -Qi "$pkg" &>/dev/null && continue
        if pacman -Si "$pkg" &>/dev/null; then repo+=("$pkg"); else aur+=("$pkg"); fi
    done

    if [[ ${#repo[@]} -gt 0 ]]; then
        echo "From the repositories: ${repo[*]}"
        echo "(this also upgrades the rest of the system — Arch doesn't support partial upgrades)"
        sudo pacman -Su --needed --noconfirm "${repo[@]}"
    fi
    if [[ ${#aur[@]} -gt 0 ]]; then
        command -v paru &>/dev/null || install_paru
        if command -v paru &>/dev/null; then
            echo "From the AUR: ${aur[*]}"
            paru -S --needed --noconfirm --skipreview "${aur[@]}"
        else
            echo "Not in the repositories and no paru to get them from the AUR: ${aur[*]}" >&2
        fi
    fi
    [[ ${#repo[@]} -eq 0 && ${#aur[@]} -eq 0 ]] && echo "Everything is installed."
    install_cursor
    return 0
}

install_cursor() {
    local d
    for d in /usr/share/icons "$HOME/.local/share/icons" "$HOME/.icons"; do
        [[ -d "$d/$CURSOR_THEME/cursors" ]] && return 0
    done
    echo "Cursor theme $CURSOR_THEME → ~/.local/share/icons"
    mkdir -p "$HOME/.local/share/icons"
    curl -fsSL "$CURSOR_URL" | tar -xJ -C "$HOME/.local/share/icons" \
        || echo "!! Downloading the cursor theme failed — $CURSOR_URL" >&2
}

install_paru() {
    echo "Some packages are only in the AUR — installing paru (the AUR helper) first."
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" \
        && (cd "$tmp/paru-bin" && makepkg -si --noconfirm); then
        echo "paru installed."
    else
        echo "!! Installing paru failed — AUR packages are skipped." >&2
    fi
    rm -rf "$tmp"
}

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

copy_configs() {
    local dry="${1:-0}" f src dst backup="" changed=0 new=0
    [[ "$dry" == 1 ]] || backup="$STATE_DIR/deploy-backup/$(date +%Y%m%d-%H%M%S)"
    echo "== Configs → $HOME${backup:+ (changed files backed up to $backup)}"

    while IFS= read -r f; do
        src="$DOTFILES/$f"
        dst="$HOME/$f"
        if [[ -L "$dst" ]]; then
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

post_deploy() {
    echo "== Session setup"
    systemctl --user daemon-reload

    command -v ya >/dev/null && ya pkg install >/dev/null 2>&1 || true

    if ! in_session; then
        echo "Not inside a running niri session — log into niri, then run"
        echo "  ~/.local/bin/apply-wallpaper-theme.sh ~/Pictures/Wallpapers/<some wallpaper>"
        echo "to generate the colours (quickshell won't start without Colors.js)."
        return 0
    fi

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

    systemctl --user try-restart niri-rice-quickshell.service niri-rice-audio-sync.service \
        2>/dev/null || true
    systemctl --user start niri-rice-cliphist.service 2>/dev/null || true
    pkill -USR2 -x waybar 2>/dev/null || true
    command -v makoctl >/dev/null && makoctl reload 2>/dev/null || true
    echo "Done."
}

system_setup() {
    echo "== System integration"
    local share="$HOME/.local/share"

    if ask "Power modes (rp-power: sudoers rule, udev rule on AC, systemd units)?"; then
        sudo "$share/rp-power/install.sh"
    fi
    if pacman -Qi lightdm &>/dev/null && ask "Mirror the theme and wallpaper to the LightDM login screen (rp-lightdm-sync)?"; then
        sudo "$share/rp-lightdm-sync/install.sh"
    fi
    echo
    echo "The quickshell login screen replaces the current display manager with greetd (back with --revert)."
    echo "Preview it first: $share/rp-greeter/preview.sh"
    if ask "Switch the login screen to rp-greeter now?"; then
        sudo "$share/rp-greeter/install.sh"
    fi
}

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
        1) choose_extras; need_sudo; install_packages; copy_configs; post_deploy
           echo; ask "Also run the system integration steps?" && system_setup
           break ;;
        2) choose_extras; need_sudo; install_packages; break ;;
        3) copy_configs; post_deploy; break ;;
        4) copy_configs 1; break ;;
        5) stow_configs; post_deploy; break ;;
        6) need_sudo; system_setup; break ;;
        7) exit 0 ;;
        *) echo "Pick a number from the list." ;;
    esac
done
