#!/usr/bin/env bash
set -euo pipefail

ZEN_BASE="$HOME/.var/app/app.zen_browser.zen/.zen"
SRC="$HOME/.config/zen"

[[ -d "$ZEN_BASE" && -f "$SRC/userChrome.css" && -f "$SRC/userContent.css" ]] || exit 0

alpha="$("$HOME/.local/bin/rp-settings" get theme.terminal_opacity 2>/dev/null || echo 0.45)"

while IFS= read -r profile; do
    [[ -f "$profile/prefs.js" ]] || continue
    mkdir -p "$profile/chrome"
    { cat "$SRC/userChrome.css"; printf ':root:not([zen-private-window="true"]) { --rp-alpha: %s; }\n' "$alpha"; } \
        >"$profile/chrome/userChrome.css"
    cat "$SRC/userContent.css" >"$profile/chrome/userContent.css"

    cat >"$profile/user.js" <<EOF
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("zen.view.window.scheme", 0);
user_pref("zen.widget.linux.transparency", true);
user_pref("browser.tabs.allow_transparent_browser", true);
EOF

done < <(find "$ZEN_BASE" -mindepth 1 -maxdepth 1 -type d ! -name "Profile Groups" 2>/dev/null)
