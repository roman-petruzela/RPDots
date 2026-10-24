#!/usr/bin/env bash
set -uo pipefail

fails=0
ok() { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }

echo ":: Verifying the installation"

for c in niri qs matugen awww kitty fuzzel cliphist swayidle grim jq zsh magick; do
    check "command $c" command -v "$c"
done
check "oh-my-zsh package" test -f /usr/share/oh-my-zsh/oh-my-zsh.sh
check "cursor theme system-wide" test -d /usr/share/icons/Bibata-Modern-Ice/cursors
check "login shell is zsh" bash -c '[[ $(getent passwd "$USER" | cut -d: -f7) == */zsh ]]'
check "zshrc loads without errors" bash -c '! script -qec "zsh -i -c true" /dev/null 2>&1 | grep -iE "not found|no such|error|parse"'

for f in .config/niri/config.kdl .config/quickshell/shell.qml .local/bin/rp-settings .config/matugen/config.toml \
    .config/niri-rice/dotfiles-path; do
    check "deployed $f" test -f "$HOME/$f"
done
check "nothing left to deploy" bash -c '! ~/dotfiles/install.sh diff | grep -qE "^  (changed|new) "'
check "no waybar/eww/rofi leftovers" bash -c '! ls ~/.config/waybar ~/.config/eww ~/.config/rofi 2>/dev/null | grep -q .'

check "rp-settings apply" "$HOME/.local/bin/rp-settings" apply
check "settings.kdl keyboard is us" grep -q 'layout "us"' "$HOME/.config/niri/settings.kdl"
check "niri config valid" niri validate -c "$HOME/.config/niri/config.kdl"

"$HOME/.local/bin/apply-wallpaper-theme.sh" >/tmp/theme.log 2>&1
check "theme pipeline exits 0" test $? -eq 0
check "Colors.js generated" test -s "$HOME/.config/quickshell/Colors.js"
check "kitty theme generated" test -s "$HOME/.config/kitty/current-theme.conf"
check "no failed theme module" bash -c '! grep -q "rc=[1-9]" ~/.cache/niri-rice/theme-modules.log'

qml_errors=0
while IFS= read -r f; do
    /usr/lib/qt6/bin/qmllint "$f" >/dev/null 2>&1 || { echo "    qmllint: $f"; qml_errors=1; }
done < <(find "$HOME/.config/quickshell" -name '*.qml')
check "quickshell QML parses" test $qml_errors -eq 0

check "greeter files installed" test -f /usr/share/rp-greeter/greeter/lock/LockContent.qml
check "greeter niri.kdl valid" niri validate -c /usr/share/rp-greeter/niri.kdl
check "greeter keyboard follows settings" grep -q 'layout "us"' /usr/share/rp-greeter/niri.kdl
check "greetd enabled" test -L /etc/systemd/system/display-manager.service
check "greeter sync runs without password" sudo -n rp-lightdm-sync-apply
check "rp-power helper installed" test -x /usr/local/bin/rp-power-apply

echo
if [[ $fails -eq 0 ]]; then echo ":: All checks passed"; else echo ":: $fails check(s) failed"; fi
exit $((fails > 0))
