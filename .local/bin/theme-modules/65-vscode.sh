#!/usr/bin/env bash
set -euo pipefail

settings_file="$HOME/.config/Code/User/settings.json"
mkdir -p "$(dirname "$settings_file")"
[[ -f "$settings_file" ]] || printf '{}\n' > "$settings_file"
command -v jq >/dev/null 2>&1 || exit 0

tmp="$(mktemp)"
jq \
  --arg background "$background" \
  --arg foreground "$foreground" \
  --arg color0 "$color0" \
  --arg color1 "$color1" \
  --arg color2 "$color2" \
  --arg color3 "$color3" \
  --arg color4 "$color4" \
  --arg color5 "$color5" \
  --arg color6 "$color6" \
  --arg color7 "$color7" \
  --arg color8 "$color8" \
  --arg color9 "$color9" \
  --arg color10 "$color10" \
  --arg color11 "$color11" \
  --arg color12 "$color12" \
  --arg color13 "$color13" \
  --arg color14 "$color14" \
  --arg color15 "$color15" \
  --arg accent "$accent" \
  --arg accent_blue "$accent_blue" \
  --arg accent_soft "$accent_soft" \
  --arg accent_urgent "$accent_urgent" \
  '
  .["workbench.colorCustomizations"] = {
    "editor.background": $background,
    "editor.foreground": $foreground,
    "editorLineNumber.foreground": $color8,
    "editorLineNumber.activeForeground": $accent_blue,
    "editorCursor.foreground": $accent,
    "editor.selectionBackground": ($accent + "44"),
    "editor.inactiveSelectionBackground": ($accent_soft + "2e"),
    "editor.wordHighlightBackground": ($accent_blue + "30"),
    "editor.wordHighlightStrongBackground": ($accent + "36"),
    "editor.findMatchBackground": ($accent + "55"),
    "editor.findMatchHighlightBackground": ($accent_soft + "3a"),
    "editorGroupHeader.tabsBackground": $color0,
    "tab.activeBackground": $background,
    "tab.inactiveBackground": $color0,
    "tab.activeForeground": $foreground,
    "tab.inactiveForeground": $color8,
    "activityBar.background": $color0,
    "activityBar.foreground": $accent_blue,
    "activityBarBadge.background": $accent,
    "activityBarBadge.foreground": $background,
    "statusBar.background": $color0,
    "statusBar.foreground": $foreground,
    "statusBarItem.remoteBackground": $accent,
    "statusBarItem.remoteForeground": $background,
    "sideBar.background": $color0,
    "sideBar.foreground": $foreground,
    "titleBar.activeBackground": $color0,
    "titleBar.activeForeground": $foreground,
    "terminal.background": $background,
    "terminal.foreground": $foreground,
    "terminal.ansiBlack": $color0,
    "terminal.ansiRed": $color1,
    "terminal.ansiGreen": $color2,
    "terminal.ansiYellow": $color3,
    "terminal.ansiBlue": $color4,
    "terminal.ansiMagenta": $color5,
    "terminal.ansiCyan": $color6,
    "terminal.ansiWhite": $color7,
    "terminal.ansiBrightBlack": $color8,
    "terminal.ansiBrightRed": $color9,
    "terminal.ansiBrightGreen": $color10,
    "terminal.ansiBrightYellow": $color11,
    "terminal.ansiBrightBlue": $color12,
    "terminal.ansiBrightMagenta": $color13,
    "terminal.ansiBrightCyan": $color14,
    "terminal.ansiBrightWhite": $color15,
    "diffEditor.insertedTextBackground": ($color2 + "2b"),
    "diffEditor.removedTextBackground": ($accent_urgent + "30")
  }
  | .["editor.tokenColorCustomizations"] = {
    "comments": $color8,
    "keywords": $color1,
    "functions": $color5,
    "strings": $color2,
    "numbers": $color4,
    "types": $accent_blue,
    "variables": $foreground
  }
  ' "$settings_file" > "$tmp"

mv "$tmp" "$settings_file"
