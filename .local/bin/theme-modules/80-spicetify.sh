#!/usr/bin/env bash
set -euo pipefail

if command -v spicetify >/dev/null 2>&1 && [[ -d "$HOME/.config/spicetify" ]]; then
    state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/niri-rice"
    mkdir -p "$state_dir"
    theme_dir="$HOME/.config/spicetify/Themes/PywalDynamic"
    mkdir -p "$theme_dir"

    log_file="$state_dir/spicetify.log"
    echo "--- Spuštění skriptu $(date) ---" >"$log_file"

    # 1. ZÁPIS BAREV
    cat >"$theme_dir/color.ini" <<EOF
[wal]
text                = ${color6#\#}
subtext             = ${color7#\#}
main                = ${background#\#}
main-elevated       = ${color0#\#}
sidebar             = ${color0#\#}
player              = ${background#\#}
card                = ${color0#\#}
shadow              = 000000
selected-row        = ${color8#\#}
button              = ${accent#\#}
button-active       = ${accent_blue#\#}
button-disabled     = ${color8#\#}
tab-active          = ${accent_soft#\#}
notification        = ${accent#\#}
notification-error = ${accent_urgent#\#}
misc                = ${accent#\#}
EOF

    cat >"$theme_dir/user.css" <<EOF
:root {
  --spice-text: ${color6};
  --spice-subtext: ${color7};
  --spice-button: ${accent};
  --spice-button-active: ${accent_blue};
  --spice-button-disabled: ${color8};
}
EOF

    spicetify config current_theme PywalDynamic >>"$log_file" 2>&1
    spicetify config color_scheme wal >>"$log_file" 2>&1

    # 2. STRATEGICKÉ ZÁLOHOVÁNÍ: Zjistíme ID workspace, kde Spotify právě žije
    TARGET_WORKSPACE=""
    if command -v niri >/dev/null 2>&1 && pgrep -x spotify >/dev/null 2>&1; then
        # Vytáhneme ID workspace pro okno s app_id "spotify"
        TARGET_WORKSPACE=$(niri msg --json windows | jq -r '.[] | select(.app_id=="spotify") | .workspace_id' 2>/dev/null || echo "")
    fi

    # 3. REBOOT SPOTIFY PŘES SPICETIFY
    spicetify apply -q >>"$log_file" 2>&1 || spicetify backup apply -q >>"$log_file" 2>&1 || true
    # 3. OVLÁDÁNÍ HUDBY (Na pozadí s agresivnějším startem)
    (
        # Počkáme, dokud systém Spotify vůbec nezaregistruje jako přehrávač
        for i in {1..40}; do
            if playerctl --list-all 2>/dev/null | grep -q "spotify"; then
                sleep 0.8

                # Zkusíme nejdříve standardní cestu
                if playerctl --player=spotify play 2>/dev/null; then
                    break
                fi

                # Pokud to selhalo (prázdná fronta), nasimulujeme globální MediaPlay klávesu přes ydotool/wtype
                # nebo přímo pošleme specifický MPRIS příkaz pro vynucení startu
                playerctl --player=spotify play-pause >>"$log_file" 2>&1 || true
                break
            fi
            sleep 0.2
        done
    ) &
    # 4. PO-RESTARTOVÁ AUTOMATIZACE (Místo + Hudba)
    if [[ -n "$TARGET_WORKSPACE" ]]; then
        (
            # Smyčka, která čeká na nové okno Spotify
            for i in {1..40}; do
                if niri msg --json windows | jq -e '.[] | select(.app_id=="spotify")' >/dev/null 2>&1; then
                    SPOTIFY_WINDOW_ID=$(niri msg --json windows | jq '.[] | select(.app_id=="spotify") | .id')

                    # A: Přesuneme okno EXPLICITNĚ na původní workspace
                    niri msg action move-window-to-workspace "$TARGET_WORKSPACE" >/dev/null 2>&1

                    # B: Počkáme malý moment, než Spotify plně inicializuje svůj audio subsystém
                    sleep 0.5

                    # C: Pustíme hudbu (zkusíme to přes playerctl, pokud selže, pošleme simulaci klávesy Space)
                    if playerctl --player=spotify status >/dev/null 2>&1; then
                        playerctl --player=spotify play
                    else
                        # Alternativní pokus, pokud MPRIS ještě neodpovídá: zaměříme okno a pošleme "Play"
                        niri msg action focus-window --id "$SPOTIFY_WINDOW_ID" >/dev/null 2>&1
                        playerctl play || true
                    fi
                    break
                fi
                sleep 0.1
            done
        ) &
    fi
fi
