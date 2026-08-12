#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

PKGS=(
    niri
    waybar
    kitty
    mako
    fuzzel
    swaylock-effects
    kanshi
    cava
    btop
    rofi-wayland
    fastfetch
    awww
    mpvpaper
    matugen
    quickshell
    imagemagick
    playerctl
    brightnessctl
    wireplumber
    jq
    eza
    zsh
    zoxide
    atuin
    fnm
    ttf-jetbrains-mono-nerd
    papirus-icon-theme
    nwg-look
    qt5ct
    qt6ct
    thunar
    thunar-archive-plugin
    thunar-volman
    xfce4-settings
    gvfs
    gvfs-smb
    gvfs-afc
    tumbler
    ffmpegthumbnailer
)

install_packages() {
    echo "Installing packages..."
    local missing=()
    for pkg in "${PKGS[@]}"; do
        pacman -Qi "$pkg" &>/dev/null || missing+=("$pkg")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing: ${missing[*]}"
        sudo pacman -S --needed "${missing[@]}"
    else
        echo "All packages are already installed."
    fi
}

stow_dotfiles() {
    echo "Symlinking configs with stow..."
    cd "$DOTFILES"
    stow --target="$HOME" --restow .
    echo "Done."
}

echo "=== Dotfiles install ==="
echo "Dotfiles: $DOTFILES"
echo ""

echo "What do you want to do?"
select action in "Install packages" "Symlink configs (stow)" "Both" "Cancel"; do
    case "$action" in
        "Install packages") install_packages; break ;;
        "Symlink configs (stow)") stow_dotfiles; break ;;
        "Both") install_packages; stow_dotfiles; break ;;
        "Cancel") exit 0 ;;
    esac
done
