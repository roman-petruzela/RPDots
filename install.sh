#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "error: run as a regular user; the installer calls sudo itself" >&2
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
    pipewire-audio
    sound-theme-freedesktop
    libpulse
    pavucontrol
    networkmanager
    nm-connection-editor
    rsync
    stow
    git

    zsh
    zsh-theme-powerlevel10k
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
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
    echo ":: Root access is required"
    sudo -v || { echo "error: sudo authentication failed" >&2; exit 1; }
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
    echo ":: Optional packages (~350 MB):"
    printf '  %s\n' "${EXTRAS[@]}"
    ask "Install optional packages?" && WANT_EXTRAS=1
    return 0
}

install_packages() {
    echo ":: Installing packages"
    local list=("${PKGS[@]}")
    [[ $WANT_EXTRAS == 1 ]] && list+=("${EXTRAS[@]}")
    sudo pacman -Sy
    local pkg repo=() aur=()
    for pkg in "${list[@]}"; do
        pacman -Qi "$pkg" &>/dev/null && continue
        if pacman -Si "$pkg" &>/dev/null; then repo+=("$pkg"); else aur+=("$pkg"); fi
    done

    if [[ ${#repo[@]} -gt 0 ]]; then
        echo " -> Repositories (with full system upgrade): ${repo[*]}"
        sudo pacman -Su --needed --noconfirm "${repo[@]}"
    fi
    if [[ ${#aur[@]} -gt 0 ]]; then
        command -v paru &>/dev/null || install_paru
        if command -v paru &>/dev/null; then
            echo " -> AUR: ${aur[*]}"
            paru -S --needed --noconfirm --skipreview "${aur[@]}"
        else
            echo "warning: paru unavailable, skipping AUR packages: ${aur[*]}" >&2
        fi
    fi
    [[ ${#repo[@]} -eq 0 && ${#aur[@]} -eq 0 ]] && echo " -> All packages already installed"
    install_rp_audio
    install_cursor
    install_zsh
    return 0
}

install_rp_audio() {
    pacman -Qq rp-audio-git &>/dev/null && return 0
    echo " -> Building rp-audio"
    local tmp; tmp="$(mktemp -d)"
    git clone -q --depth 1 https://github.com/roman-petruzela/rp-audio.git "$tmp/rp-audio" \
        && (cd "$tmp/rp-audio" && makepkg -si --noconfirm) \
        && systemctl --user enable rp-audio.service 2>/dev/null \
        || echo "warning: rp-audio installation failed" >&2
    rm -rf "$tmp"
}

install_zsh() {
    local custom="$HOME/.oh-my-zsh/custom/plugins" p
    [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] \
        || git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh" \
        || echo "warning: failed to clone oh-my-zsh" >&2
    for p in zsh-autosuggestions zsh-syntax-highlighting; do
        [[ -d "$custom/$p" ]] || git clone -q --depth 1 "https://github.com/zsh-users/$p" "$custom/$p" \
            || echo "warning: failed to clone $p" >&2
    done
    [[ "$(getent passwd "$USER" | cut -d: -f7)" == */zsh ]] || sudo chsh -s /usr/bin/zsh "$USER"
}

install_cursor() {
    local d
    for d in /usr/share/icons "$HOME/.local/share/icons" "$HOME/.icons"; do
        [[ -d "$d/$CURSOR_THEME/cursors" ]] && return 0
    done
    echo " -> Installing cursor theme $CURSOR_THEME"
    mkdir -p "$HOME/.local/share/icons"
    curl -fsSL "$CURSOR_URL" | tar -xJ -C "$HOME/.local/share/icons" \
        || echo "warning: failed to download $CURSOR_URL" >&2
}

install_paru() {
    echo " -> Installing paru"
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    git clone -q --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" \
        && (cd "$tmp/paru-bin" && makepkg -si --noconfirm) \
        || echo "warning: paru installation failed" >&2
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

remember_dotfiles() {
    mkdir -p "$HOME/.config/niri-rice" "$STATE_DIR"
    printf '%s\n' "$DOTFILES" >"$HOME/.config/niri-rice/dotfiles-path"
    git -C "$DOTFILES" rev-parse HEAD >"$STATE_DIR/deployed-commit" 2>/dev/null || true
}

copy_configs() {
    local dry="${1:-0}" f src dst backup="" changed=0 new=0
    [[ "$dry" == 1 ]] || backup="$STATE_DIR/deploy-backup/$(date +%Y%m%d-%H%M%S)"
    echo ":: Deploying configs to $HOME"

    while IFS= read -r f; do
        src="$DOTFILES/$f"
        dst="$HOME/$f"
        if [[ -L "$dst" ]]; then
            [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]] && continue
        elif [[ -f "$dst" ]]; then
            cmp -s "$src" "$dst" && continue
            changed=$((changed + 1))
            [[ "$dry" == 1 ]] && echo "  changed  $f"
        else
            new=$((new + 1))
            [[ "$dry" == 1 ]] && echo "  new      $f"
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

    echo " -> $new new, $changed updated"
    [[ "$dry" != 1 && $changed -gt 0 ]] && echo " -> Replaced files backed up to $backup"
    if [[ "$dry" != 1 && $changed -eq 0 && -n "$backup" ]]; then rmdir -p "$backup" 2>/dev/null || true; fi
    if [[ "$dry" != 1 ]] && command -v niri >/dev/null; then
        niri validate -c "$HOME/.config/niri/config.kdl" >/dev/null 2>&1 \
            || echo "warning: niri config validation failed" >&2
    fi
}

stow_configs() {
    echo ":: Linking configs with stow"
    stow --dir="$DOTFILES" --target="$HOME" --restow .
}

post_deploy() {
    echo ":: Configuring session"
    systemctl --user daemon-reload

    command -v ya >/dev/null && ya pkg install >/dev/null 2>&1 || true

    if ! in_session; then
        echo " -> The theme is generated on the first login to niri"
        return 0
    fi

    if [[ ! -f "$HOME/.config/quickshell/Colors.js" ]]; then
        echo " -> Generating theme"
        "$HOME/.local/bin/apply-wallpaper-theme.sh" >/dev/null 2>&1 || echo "warning: theme generation failed" >&2
    fi

    systemctl --user try-restart niri-rice-quickshell.service rp-audio.service \
        2>/dev/null || true
    systemctl --user start niri-rice-cliphist.service 2>/dev/null || true
    pkill -USR2 -x waybar 2>/dev/null || true
    echo ":: Done"
}

system_setup() {
    echo ":: System integration"
    local share="$HOME/.local/share"

    if ask "Ask for the password once per system update instead of once per package (polkit rule)?"; then
        sudo install -Dm644 "$DOTFILES/.local/share/rp-sys/49-rp-pacman.rules" /etc/polkit-1/rules.d/49-rp-pacman.rules
    fi
    if ask "Install power profiles (rp-power)?"; then
        sudo "$share/rp-power/install.sh"
    fi
    if pacman -Qi lightdm &>/dev/null && ask "Apply the theme to the LightDM greeter?"; then
        sudo "$share/rp-lightdm-sync/install.sh"
    fi
    echo " -> The RPRice login screen replaces the current display manager with greetd"
    echo " -> Preview: $share/rp-greeter/preview.sh, revert: $share/rp-greeter/install.sh --revert"
    if ask "Install the RPRice login screen?"; then
        sudo "$share/rp-greeter/install.sh"
    fi
}

pull_repo() {
    git -C "$DOTFILES" rev-parse --is-inside-work-tree &>/dev/null || { echo " -> Not a git checkout, skipping pull"; return 0; }
    git -C "$DOTFILES" rev-parse --abbrev-ref '@{upstream}' &>/dev/null || { echo " -> No upstream branch, skipping pull"; return 0; }
    echo ":: Pulling $(git -C "$DOTFILES" rev-parse --abbrev-ref '@{upstream}')"
    [[ -t 0 ]] || export GIT_TERMINAL_PROMPT=0
    if ! git -C "$DOTFILES" pull --rebase --autostash --quiet; then
        echo "error: git pull failed; resolve it in $DOTFILES and run ./install.sh update again" >&2
        exit 1
    fi
}

UPDATED=()
merge_configs() {
    local base="$1" f src dst old tmp backup new=0 updated=0 merged=0 kept=0
    local -a conflicts=()
    backup="$STATE_DIR/deploy-backup/$(date +%Y%m%d-%H%M%S)"
    tmp="$(mktemp -d)"
    echo ":: Updating configs in $HOME (base ${base:0:7})"

    while IFS= read -r f; do
        src="$DOTFILES/$f"
        dst="$HOME/$f"
        if [[ ! -e "$dst" && ! -L "$dst" ]]; then
            mkdir -p "$(dirname "$dst")"
            cp -p "$src" "$dst"
            UPDATED+=("$f"); new=$((new + 1))
            continue
        fi
        cmp -s "$src" "$dst" && continue
        old="$tmp/base"
        if ! git -C "$DOTFILES" show "$base:$f" >"$old" 2>/dev/null; then
            cp -p "$src" "$dst.new"; conflicts+=("$f"); continue
        fi
        cmp -s "$old" "$src" && { kept=$((kept + 1)); continue; }
        mkdir -p "$backup/$(dirname "$f")"
        cp -P "$dst" "$backup/$f"
        if cmp -s "$old" "$dst"; then
            cp -p "$src" "$dst"
            UPDATED+=("$f"); updated=$((updated + 1))
        elif cp "$dst" "$tmp/merged" && git merge-file -q "$tmp/merged" "$old" "$src" 2>/dev/null; then
            cat "$tmp/merged" >"$dst"
            UPDATED+=("$f"); merged=$((merged + 1))
        else
            cp -p "$src" "$dst.new"; conflicts+=("$f")
        fi
    done < <(repo_files)

    while IFS= read -r f; do
        [[ -z "$f" || -e "$DOTFILES/$f" || ! -f "$HOME/$f" ]] && continue
        git -C "$DOTFILES" show "$base:$f" 2>/dev/null | cmp -s - "$HOME/$f" || continue
        mkdir -p "$backup/$(dirname "$f")"
        mv "$HOME/$f" "$backup/$f"
        echo "  removed  $f"
    done < <(git -C "$DOTFILES" diff --name-only --diff-filter=D "$base" HEAD 2>/dev/null)

    rm -rf "$tmp"
    echo " -> $new new, $updated updated, $merged merged with your changes, $kept kept as you changed them"
    [[ -d "$backup" ]] && echo " -> Previous versions backed up to $backup"
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo " -> Your changes conflict with the update; the new version is next to yours as .new:"
        printf '      ~/%s.new\n' "${conflicts[@]}"
    fi
    return 0
}

update_packages() {
    local pkg missing=()
    for pkg in "${PKGS[@]}"; do
        pacman -T "$pkg" &>/dev/null || missing+=("$pkg")
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0
    echo ":: Installing new dependencies: ${missing[*]}"
    "$HOME/.local/bin/rp-sys" install "${missing[@]}" || echo "warning: package installation failed" >&2
}

update_units() {
    local f unit restart=()
    systemctl --user daemon-reload
    for f in "${UPDATED[@]}"; do
        [[ "$f" == .config/systemd/user/* ]] || continue
        unit="${f##*/}"
        grep -q '^\[Install\]' "$HOME/$f" && ! systemctl --user is-enabled -q "$unit" 2>/dev/null \
            && systemctl --user enable --now "$unit" 2>/dev/null && echo " -> Enabled $unit"
    done
    for unit in $(systemctl --user list-units --type=service --state=running --no-legend --plain 'niri-rice-*' | awk '{print $1}'); do
        [[ "$unit" == niri-rice-quickshell.service ]] && continue
        for f in "${UPDATED[@]}"; do
            if [[ "$f" == ".config/systemd/user/$unit" ]] \
                || systemctl --user cat "$unit" 2>/dev/null | grep -q "^ExecStart=.*${f##*/}"; then
                restart+=("$unit"); break
            fi
        done
    done
    if [[ ${#restart[@]} -gt 0 ]]; then
        systemctl --user try-restart "${restart[@]}" && echo " -> Restarted ${restart[*]}"
    fi
    return 0
}

run_update() {
    local base
    base="$(cat "$STATE_DIR/deployed-commit" 2>/dev/null \
        || git -C "$DOTFILES" rev-parse -q --verify ORIG_HEAD 2>/dev/null || git -C "$DOTFILES" rev-parse HEAD)"
    if [[ "${1:-}" != --pulled ]]; then
        pull_repo
        exec "$DOTFILES/install.sh" update --pulled "$base"
    fi
    base="${2:-$base}"
    git -C "$DOTFILES" cat-file -e "$base^{commit}" 2>/dev/null || base="$(git -C "$DOTFILES" rev-parse HEAD)"
    merge_configs "$base"
    remember_dotfiles
    update_packages
    update_units
    if command -v niri >/dev/null && ! niri validate -c "$HOME/.config/niri/config.kdl" >/dev/null 2>&1; then
        echo "warning: niri config validation failed" >&2
    fi
    echo ":: RPDots is up to date ($(git -C "$DOTFILES" log -1 --format='%h %s' 2>/dev/null))"
}

case "${1:-}" in
    update) shift; run_update "$@"; exit 0 ;;
    "") ;;
    *) echo "usage: ./install.sh [update]" >&2; exit 2 ;;
esac

echo "RPDots installer ($DOTFILES)"
echo

PS3="> "
select action in \
    "Full install" \
    "Packages only" \
    "Configs only" \
    "Preview config changes" \
    "Configs as stow symlinks" \
    "System integration" \
    "Quit"; do
    case "$REPLY" in
        1) choose_extras; need_sudo; install_packages; copy_configs; remember_dotfiles; post_deploy
           echo; ask "Run system integration?" && system_setup
           break ;;
        2) choose_extras; need_sudo; install_packages; break ;;
        3) copy_configs; remember_dotfiles; post_deploy; break ;;
        4) copy_configs 1; break ;;
        5) stow_configs; remember_dotfiles; post_deploy; break ;;
        6) need_sudo; system_setup; break ;;
        7) exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
done
