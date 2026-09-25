#!/usr/bin/env bash
set -euo pipefail
# priority: 66

ZEN_BASE="$HOME/.var/app/app.zen_browser.zen/.zen"

[[ -d "$ZEN_BASE" ]] || exit 0

while IFS= read -r profile; do
    mkdir -p "$profile/chrome"

    cat > "$profile/chrome/userChrome.css" <<EOF
:root {
  --rp-bg:      ${background};
  --rp-surface: ${color0};
  --rp-fg:      ${foreground};
  --rp-accent:  ${accent};
  --rp-border:  ${accent}55;
}

/* toolbar */
#navigator-toolbox {
  background-color: var(--rp-bg) !important;
  color: var(--rp-fg) !important;
  border-bottom: 1px solid var(--rp-border) !important;
}

/* selected tab */
.tab-background[selected="true"] {
  background-color: color-mix(in srgb, var(--rp-bg) 70%, var(--rp-accent)) !important;
  outline: 1px solid ${accent}44 !important;
}
EOF

    cat > "$profile/chrome/userContent.css" <<EOF
@-moz-document url-prefix("about:newtab"), url-prefix("about:home") {
  :root { color-scheme: dark; }
  body { background: ${background} !important; color: ${foreground} !important; }
}
EOF

    cat > "$profile/user.js" <<EOF
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
EOF

done < <(find "$ZEN_BASE" -mindepth 1 -maxdepth 1 -type d \
    ! -name "Profile Groups" 2>/dev/null)
