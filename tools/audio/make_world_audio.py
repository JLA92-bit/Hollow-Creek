"""Synthesises the world's ambience, music and story cues, then encodes them as small mono Ogg Vorbis.

Usage: python3 tools/audio/make_world_audio.py
Writes assets/audio/world/*.ogg (ambience, rain, cues) and assets/audio/music/*.ogg (the title and
dance music, which ship in the background pack). Deterministic. Needs numpy and ffmpeg.
Everything here is our own synthesis, so there is nothing to credit.
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 22050
ROOT = Path(__file__).resolve().parents[2] / "assets" / "audio"
rng = np.random.default_rng(1952)


def t_(sec):
    return np.arange(int(RATE * sec)) / RATE


def lowpass(x, k):
    """A one-pole low-pass; k is the cut as a fraction of the sample rate times 2pi."""
    a = np.exp(-k)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = a * acc + (1 - a) * v
        out[i] = acc
    return out


def fast_lowpass(x, width):
    kern = np.ones(width) / width
    return np.convolve(x, kern, mode="same")


def loopify(x, fade=0.6):
    """Makes a seamless loop by cross-fading the end into the start."""
    n = int(RATE * fade)
    out = x[:-n].copy()
    ramp = np.linspace(0, 1, n)
    out[:n] = out[:n] * ramp + x[-n:] * (1 - ramp)
    return out


def env(n, attack, decay):
    t = np.arange(n) / RATE
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.exp(-t / decay)


def write_ogg(name, sig, folder, gain=0.6, q=1):
    sig = sig / max(1e-6, np.max(np.abs(sig))) * gain
    out = ROOT / folder
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((sig * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", str(q), "-ac", "1", "-ar", str(RATE),
                        str(out / f"{name}.ogg")], check=True)
    print("wrote", folder, name, (out / f"{name}.ogg").stat().st_size, "bytes")


# --- Ambience -------------------------------------------------------------------------------------

def wind(sec, depth=0.5):
    n = int(RATE * sec)
    base = fast_lowpass(rng.standard_normal(n), 60)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t_(sec) / (sec / 2.0) + 1.0)
    return base * swell * depth


def bird(freq, dur=0.18):
    t = t_(dur)
    sweep = freq * (1 + 0.35 * np.sin(2 * np.pi * (9 + rng.random() * 8) * t))
    return np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * env(len(t), 0.01, dur / 3)


def day_ambience():
    sec = 24
    x = wind(sec, 1.0) * 0.5
    for _ in range(26):
        at = int(rng.random() * (sec - 1.5) * RATE)
        f = float(rng.choice([2400, 3000, 3600, 4200]))
        for k in range(int(rng.integers(2, 5))):
            b = bird(f * (1 + 0.05 * k), 0.12 + rng.random() * 0.1) * (0.06 + rng.random() * 0.06)
            s = at + int(k * 0.16 * RATE)
            x[s:s + len(b)] += b[: len(x) - s]
    # A far-off magpie warble.
    for at_s in (5.0, 15.5):
        t = t_(1.2)
        w = np.sin(2 * np.pi * np.cumsum(900 + 500 * np.sin(2 * np.pi * 6 * t) + 300 * np.sin(2 * np.pi * 2.2 * t)) / RATE) * env(len(t), 0.05, 0.5)
        s = int(at_s * RATE)
        x[s:s + len(w)] += w * 0.08
    return loopify(x)


def night_ambience():
    sec = 24
    x = wind(sec, 0.5) * 0.25
    t = t_(sec)
    # Crickets: a bright tone chopped into rapid pulses, a few of them out of step.
    for f, rate, gain in ((4300, 28, 0.07), (4700, 24, 0.05), (3900, 31, 0.04)):
        pulse = np.clip(np.sin(2 * np.pi * rate * t + rng.random() * 6), 0, 1) ** 2
        slow = 0.5 + 0.5 * np.sin(2 * np.pi * t / (sec / 3.0) + rng.random() * 6)
        x += np.sin(2 * np.pi * f * t) * pulse * slow * gain
    # A frog now and then.
    for at_s in (4.0, 11.0, 19.0):
        ft = t_(0.35)
        frog = np.sin(2 * np.pi * np.cumsum(180 + 60 * np.sin(2 * np.pi * 14 * ft)) / RATE) * env(len(ft), 0.02, 0.15)
        s = int(at_s * RATE)
        x[s:s + len(frog)] += frog * 0.05
    return loopify(x)


def rain():
    sec = 10
    n = int(RATE * sec)
    hiss = fast_lowpass(rng.standard_normal(n), 3) * 0.5
    x = hiss
    for _ in range(300):
        at = int(rng.random() * (n - 800))
        d = rng.standard_normal(300) * env(300, 0.0005, 0.004) * 0.25
        x[at:at + 300] += d
    return loopify(x)


# --- Music ----------------------------------------------------------------------------------------

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def piano(freq, dur, vel=0.8):
    t = t_(dur)
    s = sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in ((1, 1.0), (2, 0.5), (3, 0.28), (4, 0.15), (5, 0.08)))
    return s * env(len(t), 0.004, 0.45 + 0.25 / max(1, freq / 200)) * vel


def squeeze(freq, dur, vel=0.5):
    """An accordion-ish reed: detuned saw-like waves, soft attack."""
    t = t_(dur)
    s = 0
    for det in (-0.004, 0.0, 0.004):
        s = s + sum(np.sin(2 * np.pi * freq * (1 + det) * h * t) / h for h in range(1, 8))
    swell = np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.06, 0, 1)
    return fast_lowpass(s, 4) * swell * vel * 0.4


def place(buf, at_s, snd):
    s = int(at_s * RATE)
    if s < len(buf):
        buf[s:s + len(snd)] += snd[: len(buf) - s]


def waltz(bpm, bars, key, melody_degrees, lively):
    """3/4: bass on one, chord on two and three, a melody over the top. Chords I - IV - V7 - I."""
    beat = 60.0 / bpm
    n = int(RATE * beat * 3 * bars) + RATE
    buf = np.zeros(n)
    scale = [0, 2, 4, 5, 7, 9, 11]
    chords = [([0, 4, 7], 0), ([5, 9, 12], 5), ([7, 11, 14, 17], 7), ([0, 4, 7], 0)]
    for bar in range(bars):
        chord, root = chords[bar % 4]
        t0 = bar * 3 * beat
        place(buf, t0, piano(midi(key - 24 + root), beat * 0.95, 0.9))
        for b in (1, 2):
            for note in chord[:3]:
                place(buf, t0 + b * beat, piano(midi(key - 12 + note), beat * 0.6, 0.35))
        for i in range(3):
            deg = melody_degrees[(bar * 3 + i) % len(melody_degrees)]
            note = key + scale[deg % 7] + 12 * (deg // 7)
            place(buf, t0 + i * beat, (squeeze if lively else piano)(midi(note), beat * (0.9 if lively else 1.2), 0.55))
    return loopify(buf[: int(RATE * beat * 3 * bars)], 0.5)


def title_music():
    return waltz(84, 16, 60, [4, 5, 4, 2, 4, 7, 6, 5, 4, 2, 1, 2, 0, 2, 4, 2, 1, 0, 6, 0], False)


def dance_music():
    return waltz(132, 24, 62, [7, 6, 7, 9, 7, 4, 5, 4, 5, 7, 5, 2, 4, 5, 4, 2, 0, 2, 4, 5, 7, 5, 4, 2], True)


# --- Cues -------------------------------------------------------------------------------------------

def bell(freq, dur=1.2):
    t = t_(dur)
    return sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in ((1, 1.0), (2.76, 0.4), (5.4, 0.15))) * env(len(t), 0.002, dur / 4)


def cues():
    noise = lambda d, k: fast_lowpass(rng.standard_normal(int(RATE * d)), k)
    write_ogg("search", noise(0.25, 8) * env(int(RATE * 0.25), 0.01, 0.07), "world", 0.4)
    write_ogg("found", np.concatenate([bell(880, 0.5), bell(1320, 0.9) * 0.8]), "world", 0.4)
    alert = np.zeros(int(RATE * 2.6))
    for i, f in enumerate((131, 156, 196)):
        place(alert, i * 0.35, piano(f, 2.0, 1.0))
    write_ogg("alert", alert, "world", 0.7)
    ring = np.concatenate([bell(1100, 0.12 if i % 2 == 0 else 0.1)[: int(RATE * 0.12)] for i in range(10)] + [np.zeros(int(RATE * 0.4))])
    write_ogg("phone", ring, "world", 0.4)
    solved = np.zeros(int(RATE * 3.0))
    for i, f in enumerate((262, 330, 392, 523)):
        place(solved, i * 0.28, piano(f, 2.4, 0.9))
    write_ogg("solved", solved, "world", 0.6)
    knock = np.zeros(int(RATE * 1.0))
    for i in range(3):
        k = noise(0.12, 5) * env(int(RATE * 0.12), 0.001, 0.025)
        place(knock, i * 0.3, k * 1.5 + np.sin(2 * np.pi * 150 * t_(0.12)) * env(int(RATE * 0.12), 0.001, 0.03))
    write_ogg("knock", knock, "world", 0.5)


def main():
    write_ogg("ambience_day", day_ambience(), "world", 0.5)
    write_ogg("ambience_night", night_ambience(), "world", 0.45)
    write_ogg("rain", rain(), "world", 0.5)
    cues()
    write_ogg("music_title", title_music(), "music", 0.5, 1)
    write_ogg("music_dance", dance_music(), "music", 0.5, 1)


if __name__ == "__main__":
    main()
