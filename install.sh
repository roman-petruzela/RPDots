#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# Packages to install (pacman)
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
)

install_packages() {
    echo "Instaluji balíčky..."
    local missing=()
    for pkg in "${PKGS[@]}"; do
        pacman -Qi "$pkg" &>/dev/null || missing+=("$pkg")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Chybějící: ${missing[*]}"
        sudo pacman -S --needed "${missing[@]}"
    else
        echo "Všechny balíčky jsou nainstalované."
    fi
}

stow_dotfiles() {
    echo "Symlinkuji konfigurace pomocí stow..."
    cd "$DOTFILES"
    stow --target="$HOME" --restow .
    echo "Hotovo."
}

echo "=== Dotfiles install ==="
echo "Dotfiles: $DOTFILES"
echo ""

echo "Co chceš udělat?"
select action in "Instalovat balíčky" "Symlinkovat konfigurace (stow)" "Oboje" "Zrušit"; do
    case "$action" in
        "Instalovat balíčky") install_packages; break ;;
        "Symlinkovat konfigurace (stow)") stow_dotfiles; break ;;
        "Oboje") install_packages; stow_dotfiles; break ;;
        "Zrušit") exit 0 ;;
    esac
done
