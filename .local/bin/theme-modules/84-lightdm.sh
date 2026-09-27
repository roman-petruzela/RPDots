#!/usr/bin/env bash
set -euo pipefail

# LightDM greeter (login screen) zrcadlí RPRice GTK3 téma + current wallpaper.
# Greeter běží pod vlastním uživatelem a nedostane se do domovské složky (chmod
# 700), takže kopírování do systémových cest dělá privilegovaný helper — viz
# .local/share/rp-lightdm-sync/install.sh. Dokud není nainstalovaný, requires=
# v modules.conf tenhle modul potichu přeskočí.
command -v rp-lightdm-sync-apply >/dev/null 2>&1 || exit 0
sudo -n rp-lightdm-sync-apply
