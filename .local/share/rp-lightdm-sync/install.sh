#!/usr/bin/env bash
# rp-lightdm-sync — instaluje privilegovaného pomocníka, který zrcadlí
# aktuální GTK3 téma + wallpaper do LightDM greeteru. Spustit jednou:
#
#   sudo ~/.local/share/rp-lightdm-sync/install.sh
#
# Poté theme-modules/84-lightdm.sh volá helpera automaticky při každé
# změně tapety, přes sudoers pravidlo scoped jen na tenhle jeden binary.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"

[[ $EUID -eq 0 ]] || {
    echo "Spusť s sudo: sudo $0" >&2
    exit 1
}

install -Dm755 "$SRC/rp-lightdm-sync-apply" /usr/local/bin/rp-lightdm-sync-apply

TARGET_USER="${SUDO_USER:-roman}"
cat >/etc/sudoers.d/rp-lightdm-sync <<EOF
$TARGET_USER ALL=(root) NOPASSWD: /usr/local/bin/rp-lightdm-sync-apply
EOF
chmod 0440 /etc/sudoers.d/rp-lightdm-sync
visudo -cf /etc/sudoers.d/rp-lightdm-sync

echo
echo "Hotovo. Od teď se změna tapety propíše i do LightDM greeteru automaticky."
