"""Synthesises the build-mode UI sounds as small mono WAV files (22.05 kHz, 16-bit). Deterministic.

Usage: python3 tools/audio/make_ui_sfx.py
Writes assets/audio/ui/{click,place,remove,error,undo,tick,storey}.wav
Sounds are soft and woody, to suit 1952: a timber knock for placing, a muted thud for removing.
"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "ui"
rng = np.random.default_rng(1952)


def env(n, attack=0.004, decay=0.08):
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def tone(freq, dur, decay=0.08, harmonics=((1, 1.0),)):
    n = int(RATE * dur)
    t = np.arange(n) / RATE
    s = sum(amp * np.sin(2 * np.pi * freq * h * t) for h, amp in harmonics)
    return s * env(n, decay=decay)


def knock(freq, dur=0.18, decay=0.05):
    # A wooden knock: a damped inharmonic tone plus a short filtered noise burst.
    body = tone(freq, dur, decay, ((1, 1.0), (2.76, 0.35), (5.4, 0.12)))
    n = len(body)
    noise = rng.standard_normal(n) * env(n, 0.001, 0.012)
    noise = np.convolve(noise, np.ones(6) / 6, mode="same")
    return body * 0.8 + noise * 0.35


def write(name, sig, gain=0.5):
    sig = sig / max(1e-6, np.max(np.abs(sig))) * gain
    data = (sig * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", name)


def main():
    write("click", tone(1400, 0.05, 0.012, ((1, 1.0), (2, 0.2))), 0.25)
    write("tick", tone(2200, 0.03, 0.006), 0.12)
    write("place", np.concatenate([knock(420), knock(560, 0.2) * 0.8]), 0.55)
    write("remove", knock(180, 0.25, 0.07), 0.5)
    err = tone(220, 0.22, 0.09, ((1, 1.0), (1.5, 0.5)))
    write("error", np.concatenate([err, err * 0.7]), 0.35)
    up = np.concatenate([tone(660, 0.07, 0.03), tone(520, 0.1, 0.05)])
    write("undo", up, 0.3)
    write("storey", np.concatenate([tone(520, 0.08, 0.03), tone(780, 0.12, 0.05)]), 0.3)


if __name__ == "__main__":
    main()
