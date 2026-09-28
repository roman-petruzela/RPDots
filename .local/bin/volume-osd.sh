#!/usr/bin/env bash
RP_AUDIO=rp-audio

case "${1:-up}" in
    mute) exec "$RP_AUDIO" mute toggle ;;
    *)    exec "$RP_AUDIO" volume "${1:-up}" ;;
esac
