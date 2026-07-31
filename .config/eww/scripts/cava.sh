#!/bin/bash
config_file="/tmp/cava_config_eww"
cat <<IN > "$config_file"
[general]
framerate = 60
bars = 14
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
channels = mono
IN

cava -p "$config_file" | awk '{
    bars=" ▂▃▄▅▆▇█";
    res="";
    for(i=1;i<=NF;i++) {
        res=res substr(bars, $i+1, 1);
    }
    print res;
    fflush();
}'