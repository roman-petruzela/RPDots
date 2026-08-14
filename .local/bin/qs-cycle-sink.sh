#!/usr/bin/env bash
# Přepne na další výstup. Ponecháno kvůli zpětné kompatibilitě — vlastní práci
# dělá rp-audio, které streamy nepřipichuje k zařízení (na rozdíl od
# `pactl move-sink-input`), takže dál poslouchají výchozí výstup.

exec "$HOME/.local/bin/rp-audio" cycle
