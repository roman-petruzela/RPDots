#!/usr/bin/env bash
set -euo pipefail

if [[ -d "$HOME/.config/vesktop" ]]; then
  mkdir -p "$HOME/.config/vesktop/settings"
  cat > "$HOME/.config/vesktop/settings/quickCss.css" <<EOF
:root {
  --font-primary: "Inter", "Noto Sans", "Noto Color Emoji", "Symbols Nerd Font", sans-serif;
  --font-code: "JetBrainsMono Nerd Font", "Noto Sans Mono", monospace;
  --wal-accent: ${accent};
  --wal-accent-alt: ${accent_blue};
  --wal-bg: ${background};
  --wal-fg: ${foreground};
  --wal-bg-elevated: color-mix(in srgb, var(--wal-bg) 90%, var(--wal-accent-alt));
  --wal-bg-soft: color-mix(in srgb, var(--wal-bg) 84%, var(--wal-accent));
}

body,
.theme-dark,
.theme-light {
  --font-primary: var(--font-primary) !important;
  --font-display: var(--font-primary) !important;
  --font-headline: var(--font-primary) !important;
  --font-code: var(--font-code) !important;
  --font-clan-signature: var(--font-primary) !important;
  --background-primary: var(--wal-bg) !important;
  --background-secondary: var(--wal-bg-elevated) !important;
  --background-secondary-alt: var(--wal-bg-elevated) !important;
  --background-tertiary: var(--wal-bg-soft) !important;
  --background-floating: var(--wal-bg-elevated) !important;
  --background-modifier-hover: color-mix(in srgb, var(--wal-accent) 22%, var(--wal-bg)) !important;
  --background-modifier-active: color-mix(in srgb, var(--wal-accent) 32%, var(--wal-bg)) !important;
  --channeltextarea-background: var(--wal-bg-elevated) !important;
  --text-normal: var(--wal-fg) !important;
  --header-primary: var(--wal-fg) !important;
  --interactive-active: var(--wal-fg) !important;
  --brand-500: var(--wal-accent) !important;
  --brand-560: var(--wal-accent-alt) !important;
  --brand-experiment: var(--wal-accent) !important;
}

/* Brand buttons classnames rotate often, keep selector fuzzy */
[class*="lookFilled"][class*="colorBrand"] {
  background: linear-gradient(140deg, var(--wal-accent), var(--wal-accent-alt)) !important;
  border: none !important;
}
EOF

  settings_file="$HOME/.config/vesktop/settings/settings.json"
  if command -v jq >/dev/null 2>&1 && [[ -f "$settings_file" ]]; then
    tmp="$(mktemp)"
    jq '.useQuickCss = true' "$settings_file" > "$tmp" && mv "$tmp" "$settings_file"
  fi
fi
