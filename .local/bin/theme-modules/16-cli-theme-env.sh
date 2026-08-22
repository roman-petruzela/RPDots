#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
ENV_FILE="$STATE_DIR/theme-env.sh"
P10K_FILE="$STATE_DIR/p10k-colors.zsh"
mkdir -p "$STATE_DIR"

hex="${background#\#}"
r=$((16#${hex:0:2}))
g=$((16#${hex:2:2}))
b=$((16#${hex:4:2}))
lum=$(( (2126 * r + 7152 * g + 722 * b) / 10000 ))

if (( lum >= 140 )); then
  glamour="light"
  colorfgbg="0;15"
else
  glamour="dark"
  colorfgbg="15;0"
fi

cat > "$ENV_FILE" <<EOF
#!/usr/bin/env bash
export COLORFGBG="${colorfgbg}"
export GLAMOUR_STYLE="${glamour}"
export GH_COLOR_LABELS=1
EOF
chmod 0644 "$ENV_FILE"

# P10k hex prompt colors — track wallpaper palette for new terminals
cat > "$P10K_FILE" <<EOF
typeset -g POWERLEVEL9K_DIR_FOREGROUND='${accent}'
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND='${accent_soft}'
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND='${foreground}'
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND='${color2}'
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='${color3}'
typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='${accent}'
typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND='${accent_urgent}'
typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND='${color2}'
typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND='${accent_urgent}'
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='${color3}'
typeset -g POWERLEVEL9K_TIME_FOREGROUND='${accent_soft}'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_FOREGROUND='${accent}'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND='${accent_urgent}'
typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND='${color3}'
typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND='${accent}'
EOF
chmod 0644 "$P10K_FILE"
