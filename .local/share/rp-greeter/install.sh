#!/usr/bin/env bash
# rp-greeter: login screen in quickshell (greetd → niri → quickshell), replacing
# lightdm-gtk-greeter. Run once:
#
#   sudo ~/.local/share/rp-greeter/install.sh            # install + switch to greetd
#   sudo ~/.local/share/rp-greeter/install.sh --revert   # back to LightDM
#
# Try the look first without touching the system: ~/.local/share/rp-greeter/preview.sh
#
# The switch takes effect on the next boot (or after `systemctl restart
# display-manager` from a TTY). If the greeter ever fails, log in on another
# TTY (Ctrl+Alt+F2) and run the --revert line above.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/usr/share/rp-greeter"

[[ $EUID -eq 0 ]] || {
    echo "Run with sudo: sudo $0 $*" >&2
    exit 1
}
USER_NAME="${SUDO_USER:?run through sudo so the target user is known}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

if [[ "${1:-}" == "--revert" ]]; then
    systemctl disable greetd.service
    systemctl enable lightdm.service
    echo "LightDM is back from the next boot."
    exit 0
fi

pacman -S --needed --noconfirm greetd

# Greeter QML + colours. Colors.js is refreshed on every theme change by
# rp-lightdm-sync-apply (the wallpaper already was).
install -d "$DST/greeter"
install -m644 "$SRC"/greeter/*.qml "$DST/greeter/"
install -m644 "$USER_HOME/.config/quickshell/Colors.js" "$DST/greeter/Colors.js"

# niri config: user name + the user's own output blocks (modes, scale)
outputs="$(awk '/^output /,/^}/' "$USER_HOME/.config/niri/config.kdl")"
while IFS= read -r line; do
    if [[ "$line" == "// @OUTPUTS@" ]]; then
        printf '%s\n' "$outputs"
    else
        printf '%s\n' "${line//@USER@/$USER_NAME}"
    fi
done <"$SRC/niri.kdl" >"$DST/niri.kdl"
niri validate -c "$DST/niri.kdl"

install -d -o greeter -g greeter /var/lib/rp-greeter /var/lib/rp-greeter/cache /var/lib/rp-greeter/state

# greetd config; the packaged one is kept once as config.toml.orig
if [[ -f /etc/greetd/config.toml && ! -f /etc/greetd/config.toml.orig ]]; then
    cp /etc/greetd/config.toml /etc/greetd/config.toml.orig
fi
cat >/etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "niri -c $DST/niri.kdl"
user = "greeter"
EOF

# LightDM unlocked gnome-keyring at login (/etc/pam.d/lightdm); greetd's PAM
# stack doesn't, so browser/Discord secrets would stop unlocking on their own.
PAM=/etc/pam.d/greetd
grep -q pam_gnome_keyring "$PAM" || {
    sed -i '/^auth.*include/a -auth       optional    pam_gnome_keyring.so' "$PAM"
    printf '%s\n' '-session    optional    pam_gnome_keyring.so auto_start' >>"$PAM"
}

# Updated sync helper (now also copies Colors.js for the greeter)
SUDO_USER="$USER_NAME" "$SRC/../rp-lightdm-sync/install.sh"

systemctl disable lightdm.service
systemctl enable greetd.service

echo
echo "Done. The new login screen appears on the next boot."
echo "Back to LightDM: sudo $SRC/install.sh --revert"
