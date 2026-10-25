#!/usr/bin/env bash
# Toggle the quickshell bar on the monitor under the cursor.
# Used by SUPER+J (per-monitor toggle).
set -euo pipefail

cursor_json="$(hyprctl cursorpos -j)"
cursor_x="$(echo "$cursor_json" | jq -r '.x')"
cursor_y="$(echo "$cursor_json" | jq -r '.y')"

mon_name="$(hyprctl monitors -j \
    | jq -r ".[] | select((.x <= $cursor_x) and ($cursor_x < (.x + .width)) and (.y <= $cursor_y) and ($cursor_y < (.y + .height))) | .name" \
    | head -1)"

if [[ -z "$mon_name" ]]; then
    mon_name="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')"
fi

exec qs -c ii ipc call bar toggleScreen "$mon_name"
