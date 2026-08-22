#!/usr/bin/env bash
set -euo pipefail

settings_file="$HOME/.config/vesktop/settings/settings.json"
generated="$HOME/.config/vesktop/settings/quickCss.generated.css"
live="$HOME/.config/vesktop/settings/quickCss.css"

# Matugen generuje stranou (viz output_path v ~/.config/matugen/config.toml)
# a obsah se sem preleje pres `cat`. Duvod: matugen soubor NAHRAZUJE, cimz
# vznikne novy inode a utrhne se inotify watch, ktery na quickCss.css drzi
# Vencord. Discord by pak zustal na stare palete az do restartu appky.
# `cat >` naopak existujici soubor zkrati a prepise, takze inode zustava
# a Vencord zmenu zaregistruje a prekresli se sam.
if [[ -f "$generated" ]]; then
    cat "$generated" > "$live"
fi

# Bez useQuickCss by se soubor nenacetl vubec.
if command -v jq >/dev/null 2>&1 && [[ -f "$settings_file" ]]; then
    tmp="$(mktemp)"
    jq '.useQuickCss = true' "$settings_file" > "$tmp" && mv "$tmp" "$settings_file"
fi
