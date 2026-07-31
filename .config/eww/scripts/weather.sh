#!/bin/bash
# Získá počasí z wttr.in ve formátu JSON
weather=$(curl -sf "wttr.in/?format=j1")
if [ -z "$weather" ]; then
    echo '{"temp": "N/A", "desc": "Nelze načíst"}'
else
    temp=$(echo "$weather" | jq -r '.current_condition[0].temp_C')
    desc=$(echo "$weather" | jq -r '.current_condition[0].weatherDesc[0].value')
    echo "{\"temp\": \"$temp°C\", \"desc\": \"$desc\"}"
fi