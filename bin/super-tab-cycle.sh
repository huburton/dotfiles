#!/bin/bash
# Super+Tab façon Windows :
#   - 1er appui (>1s depuis le dernier)  -> workspace précédent de cet écran (toggle 2 derniers)
#   - Appuis suivants rapprochés (<1s)   -> workspace m+1 (cycle vers le suivant existant, même écran)
STATE=/tmp/super-tab-cycle.timestamp
NOW=$(date +%s%N)
THRESHOLD_NS=1000000000   # 1 seconde

if [ -f "$STATE" ]; then
    LAST=$(cat "$STATE" 2>/dev/null)
    DELTA=$(( NOW - LAST ))
else
    DELTA=$THRESHOLD_NS
fi

echo "$NOW" > "$STATE"

if [ "$DELTA" -lt "$THRESHOLD_NS" ]; then
    hyprctl dispatch 'hl.dsp.focus({ workspace = "m+1" })'
else
    hyprctl dispatch 'hl.dsp.focus({ workspace = "previous_per_monitor" })'
fi
