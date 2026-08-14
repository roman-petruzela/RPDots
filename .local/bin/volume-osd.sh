#!/usr/bin/env bash
# Multimediální klávesy hlasitosti. Vlastní práci dělá rp-audio, aby se
# hlasitost měnila na všech výstupech naráz a přepínání mezi nimi bylo
# plynulé. OSD si rp-audio vyvolá samo.

RP_AUDIO="$HOME/.local/bin/rp-audio"

case "${1:-up}" in
    mute) exec "$RP_AUDIO" mute toggle ;;
    *)    exec "$RP_AUDIO" volume "${1:-up}" ;;
esac
