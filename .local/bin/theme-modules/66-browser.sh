#!/usr/bin/env bash
set -euo pipefail
# priority: 66
# requires: jq

setup_firefox() {
  local profile
  while IFS= read -r profile; do
    mkdir -p "$profile/chrome"
    cat > "$profile/chrome/userChrome.css" <<EOF
:root {
  --wal-bg: ${background} !important;
  --wal-fg: ${foreground} !important;
  --wal-accent: ${accent} !important;
  --toolbar-bgcolor: var(--wal-bg) !important;
  --toolbar-color: var(--wal-fg) !important;
  --lwt-accent-color: var(--wal-bg) !important;
  --lwt-text-color: var(--wal-fg) !important;
  --tab-selected-bgcolor: color-mix(in srgb, ${background} 75%, ${accent}) !important;
}
#navigator-toolbox {
  border-bottom: 1px solid ${accent}66 !important;
}
EOF
    cat > "$profile/chrome/userContent.css" <<EOF
:root {
  color-scheme: dark;
}
@-moz-document url-prefix("about:newtab"), url-prefix("about:home") {
  body {
    background: ${background} !important;
    color: ${foreground} !important;
  }
}
EOF
    cat > "$profile/user.js" <<EOF
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.in-content.dark-mode", true);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
EOF
  done < <(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name "*.default*" 2>/dev/null)
}

setup_chromium_flags() {
  cat > "$HOME/.config/chromium-flags.conf" <<EOF
--force-dark-mode
--enable-features=WebUIDarkMode
--enable-features=TouchpadOverscrollHistoryNavigation
EOF
  cat > "$HOME/.config/google-chrome-flags.conf" <<EOF
--force-dark-mode
--enable-features=WebUIDarkMode
EOF
  cat > "$HOME/.config/brave-flags.conf" <<EOF
--force-dark-mode
--enable-features=WebUIDarkMode
EOF
}

setup_chromium_profiles() {
  local pref tmp
  while IFS= read -r pref; do
    tmp="$(mktemp)"
    jq \
      --arg accent "$accent" \
      --arg bg "$background" \
      --arg fg "$foreground" \
      '
      .browser.theme = {
        "accent_color": $accent,
        "background_tab_text_color": $fg,
        "frame_color": $bg,
        "ntp_background": $bg,
        "ntp_text": $fg
      }' "$pref" > "$tmp" && mv "$tmp" "$pref"
  done < <(find "$HOME/.config" -maxdepth 4 -type f -path "*/Default/Preferences" \( -path "*/chromium/*" -o -path "*/google-chrome/*" -o -path "*/BraveSoftware/*" -o -path "*/vivaldi/*" \) 2>/dev/null)
}

setup_firefox
setup_chromium_flags
setup_chromium_profiles
