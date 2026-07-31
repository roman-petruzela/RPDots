#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.config/swaylock"
cat > "$HOME/.config/swaylock/config" <<EOF
ignore-empty-password
show-failed-attempts
screenshots
effect-blur=9x5
effect-vignette=0.5:0.5
fade-in=0.3
clock
timestr=%H:%M
datestr=%A, %d. %m.
font=JetBrainsMono Nerd Font
font-size=65
text-color=${color7}
text-clear-color=${color2}
text-wrong-color=${accent_urgent}
text-caps-lock-color=${color3}
indicator
indicator-radius=130
indicator-thickness=6
indicator-caps-lock
indicator-idle-visible
inside-color=00000033
inside-clear-color=00000033
inside-ver-color=00000033
inside-wrong-color=00000033
inside-caps-lock-color=${color3#\#}33
ring-color=${accent#\#}
ring-clear-color=${color2#\#}
ring-ver-color=${accent_soft#\#}
ring-wrong-color=${accent_urgent#\#}
ring-caps-lock-color=${color3#\#}
line-color=00000000
line-clear-color=00000000
line-ver-color=00000000
line-wrong-color=00000000
separator-color=00000000
key-hl-color=${accent_blue#\#}
bs-hl-color=${accent_urgent#\#}
caps-lock-key-hl-color=${color3#\#}
EOF
