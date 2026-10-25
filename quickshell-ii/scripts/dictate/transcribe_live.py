#!/usr/bin/env python3
"""Dictée en direct : enregistre le micro (pw-record) et re-transcrit le tampon en boucle.
Sortie (une ligne par message) : L:<niveau 0-100>  P:<texte provisoire>  F:<texte final>
SIGTERM/SIGINT = fin : dernière passe puis F:. CPU uniquement (pas de VRAM)."""
import os, re, signal, subprocess, sys, threading, time
os.environ.setdefault("HF_HOME", os.path.expanduser("~/.cache/huggingface"))
os.environ.setdefault("HF_HUB_OFFLINE", "1")
import numpy as np

BAD = re.compile(r"sous-titr|amara\.org|merci d'avoir regard|abonnez-vous|merci de votre attention|^\W*$", re.I)
stop = threading.Event()
for s in (signal.SIGTERM, signal.SIGINT):
    signal.signal(s, lambda *_: stop.set())

rec = subprocess.Popen(["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", "-"],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
chunks, lock = [], threading.Lock()

def reader():
    last = 0.0
    while True:
        b = rec.stdout.read(3200)  # 100 ms
        if not b:
            break
        a = np.frombuffer(b[: len(b) // 2 * 2], dtype=np.int16)
        with lock:
            chunks.append(a)
        now = time.time()
        if now - last > 0.1 and len(a):
            last = now
            rms = float(np.sqrt(np.mean((a.astype(np.float32) / 32768.0) ** 2)))
            print(f"L:{min(100, int(rms * 600))}", flush=True)
    stop.set()  # le micro s'est arrêté (absent/erreur)

threading.Thread(target=reader, daemon=True).start()

from faster_whisper import WhisperModel
model = WhisperModel("large-v3-turbo", device="cpu", compute_type="int8", cpu_threads=8)

def snapshot():
    with lock:
        return np.concatenate(chunks) if chunks else np.zeros(0, np.int16)

def transcribe(pcm):
    if len(pcm) < 8000:  # < 0,5 s
        return ""
    segs, _ = model.transcribe(pcm.astype(np.float32) / 32768.0, language="fr", beam_size=1,
                               vad_filter=True, condition_on_previous_text=False)
    t = " ".join(s.text.strip() for s in segs).strip()
    return "" if BAD.search(t) else t

last_n = 0
while not stop.is_set():
    pcm = snapshot()
    if len(pcm) - last_n >= 4800:  # >= 0,3 s de nouveau audio
        last_n = len(pcm)
        t = transcribe(pcm)
        if t and not stop.is_set():
            print("P:" + t.replace("\n", " "), flush=True)
    else:
        time.sleep(0.05)

rec.terminate()
print("F:" + transcribe(snapshot()).replace("\n", " "), flush=True)
