#!/usr/bin/env bash
# Push-to-talk dictation: maintenir CTRL+SPACE pour parler, relâcher pour transcrire.
# Hyprland: bind = CTRL, SPACE, exec, ~/.local/bin/whisper-ptt.sh start
#           bindr = CTRL, SPACE, exec, ~/.local/bin/whisper-ptt.sh stop
set -euo pipefail

PIDFILE=/tmp/whisper-ptt.pid
WAVFILE=/tmp/whisper-ptt.wav
MODEL=/usr/share/whisper.cpp/models/ggml-small-q5_1.bin
LANG_CODE=fr
NOTIFY_TAG="x-canonical-private-synchronous:whisper-ptt"

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -t "${2:-1500}" "$1" -h "string:${NOTIFY_TAG}" || true
}

case "${1:-}" in
  start)
    [[ -f "$PIDFILE" ]] && exit 0
    notify "Dictée — enregistrement…"
    pw-record --rate 16000 --channels 1 --format s16 "$WAVFILE" >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
    ;;
  stop)
    [[ ! -f "$PIDFILE" ]] && exit 0
    PID=$(cat "$PIDFILE")
    rm -f "$PIDFILE"
    kill -INT "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    [[ ! -s "$WAVFILE" ]] && { notify "Dictée — rien capté" 1000; exit 0; }
    notify "Dictée — transcription…" 5000
    TEXT=$(whisper-cli -m "$MODEL" -l "$LANG_CODE" -nt -np -f "$WAVFILE" 2>/dev/null \
            | tr -d '\r' | awk 'NF' | paste -sd ' ' - \
            | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    rm -f "$WAVFILE"
    if [[ -z "$TEXT" || "$TEXT" =~ ^\[.*\]$ ]]; then
      notify "Dictée — vide" 1000
      exit 0
    fi
    wtype -- "$TEXT"
    notify "✓ ${TEXT:0:60}" 1500
    ;;
  *)
    echo "usage: $0 {start|stop}" >&2; exit 2;;
esac
