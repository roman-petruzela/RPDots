#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/usr/share/rp-greeter"

[[ $EUID -eq 0 ]] || {
    echo "Run with sudo: sudo $0 $*" >&2
    exit 1
}
USER_NAME="${SUDO_USER:?run through sudo so the target user is known}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

STATE="$DST/previous"

if [[ "${1:-}" == "--revert" ]]; then
    prev_dm="$(sed -n 's/^dm=//p' "$STATE" 2>/dev/null)"
    prev_target="$(sed -n 's/^target=//p' "$STATE" 2>/dev/null)"
    systemctl disable greetd.service
    [[ -n "$prev_dm" ]] && systemctl enable "$prev_dm"
    [[ -n "$prev_target" ]] && systemctl set-default "$prev_target"
    echo "Back to ${prev_dm:-no display manager} from the next boot."
    exit 0
fi

if [[ ! -f "$USER_HOME/.config/quickshell/Colors.js" ]]; then
    echo "No theme yet ($USER_HOME/.config/quickshell/Colors.js). Log into niri once so the" >&2
    echo "theme gets generated, then run this again." >&2
    exit 1
fi

pacman -S --needed --noconfirm greetd

install -d "$DST/greeter"
install -m644 "$SRC"/greeter/*.qml "$DST/greeter/"
install -Dm644 "$SRC/../../../.config/quickshell/lock/LockContent.qml" "$DST/greeter/lock/LockContent.qml"
install -m644 "$USER_HOME/.config/quickshell/Colors.js" "$DST/greeter/Colors.js"

outputs="$(cat "$USER_HOME/.config/niri/config.kdl" "$USER_HOME/.config/niri/displays.kdl" 2>/dev/null | awk '/^output /,/^}/')"
while IFS= read -r line; do
    if [[ "$line" == "// @OUTPUTS@" ]]; then
        printf '%s\n' "$outputs"
    else
        printf '%s\n' "${line//@USER@/$USER_NAME}"
    fi
done <"$SRC/niri.kdl" >"$DST/niri.kdl"
niri validate -c "$DST/niri.kdl"

install -d -o greeter -g greeter /var/lib/rp-greeter /var/lib/rp-greeter/cache /var/lib/rp-greeter/state

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

PAM=/etc/pam.d/greetd
grep -q pam_gnome_keyring "$PAM" || {
    sed -i '/^auth.*include/a -auth       optional    pam_gnome_keyring.so' "$PAM"
    printf '%s\n' '-session    optional    pam_gnome_keyring.so auto_start' >>"$PAM"
}

SUDO_USER="$USER_NAME" "$SRC/../rp-lightdm-sync/install.sh"

cur_dm="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null)"
[[ "$cur_dm" == greetd.service || "$cur_dm" == display-manager.service ]] && cur_dm=""
install -d "$DST"
[[ -f "$STATE" ]] || printf 'dm=%s\ntarget=%s\n' "$cur_dm" "$(systemctl get-default)" >"$STATE"
[[ -n "$cur_dm" ]] && systemctl disable "$cur_dm"
systemctl enable greetd.service
[[ "$(systemctl get-default)" == graphical.target ]] || systemctl set-default graphical.target

echo
echo "Done. The new login screen appears on the next boot."
echo "Back to LightDM: sudo $SRC/install.sh --revert"
