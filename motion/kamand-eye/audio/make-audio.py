#!/usr/bin/env python3
"""Build the complete 45 s audio bed for the KAMAND EYE commercial.

- Time-stretches the ten Persian voiceover clips (pitch-preserving atempo)
- Synthesizes an upbeat 120 BPM electronic advertising bed with kicks, claps,
  hats, bass, pads, arps, impacts, risers and an end signature
- Ducks the music under each voiceover line and mixes everything to mix.wav

Requires: ffmpeg on PATH (the bundled @ffmpeg-installer binary is used by
build-audio.sh), Python 3 standard library only.
"""
import math
import os
import random
import struct
import subprocess
import wave
from array import array
from pathlib import Path

HERE = Path(__file__).resolve().parent
VO = HERE / "vo"
TIMED = HERE / "vo-timed"
OUT = HERE / "mix.wav"
FFMPEG = os.environ.get(
    "FFMPEG", str(HERE.parent.parent.parent / "node_modules/@ffmpeg-installer/linux-x64/ffmpeg")
)

SR = 24000
LENGTH = 45.5
N = int(LENGTH * SR)

# (clip, start second, atempo) — scheduled against the on-screen beats.
SCHEDULE = [
    ("01-hook.wav",      0.45, 1.12),
    ("02-solution.wav",  5.25, 1.12),
    ("03-giahi.wav",    12.40, 1.12),
    ("04-sefidak.wav",  16.40, 1.12),
    ("05-rizesh.wav",   20.40, 1.12),
    ("06-step1.wav",    25.25, 1.20),
    ("07-step2.wav",    28.10, 1.20),
    ("08-step3.wav",    30.70, 1.20),
    ("09-step4.wav",    35.00, 1.20),
    ("10-final.wav",    37.60, 1.12),
]

# ---------------------------------------------------------------------------
# 1. Time-stretch voiceover clips
# ---------------------------------------------------------------------------
def prepare_vo():
    TIMED.mkdir(parents=True, exist_ok=True)
    clips = []
    for name, start, tempo in SCHEDULE:
        src, dst = VO / name, TIMED / name
        subprocess.run(
            [FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", str(src),
             "-filter:a", f"atempo={tempo}", "-ar", str(SR), "-ac", "1", str(dst)],
            check=True,
        )
        with wave.open(str(dst), "rb") as w:
            raw = w.readframes(w.getnframes())
            pcm = array("h")
            pcm.frombytes(raw)
            samples = [v / 32768.0 for v in pcm]
        clips.append((name, start, samples))
        print(f"  VO {name:20s} at {start:5.2f}s  {len(samples)/SR:.2f}s")
    return clips


# ---------------------------------------------------------------------------
# 2. Synthesize the music bed
# ---------------------------------------------------------------------------
random.seed(7)
music = [0.0] * N


def add(buf, start, dur, fn):
    i0 = max(0, int(start * SR))
    i1 = min(len(buf), int((start + dur) * SR))
    for i in range(i0, i1):
        t = (i - i0) / SR
        buf[i] += fn(t)


def sine(freq, amp, dur, attack=0.004, release=None, phase=0.0):
    release = release if release is not None else dur * 0.8
    def f(t):
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if t > dur - release:
            env *= max(0.0, (dur - t) / release)
        return amp * env * math.sin(2 * math.pi * freq * t + phase)
    return f


def pluck(freq, amp, dur, decay=7.0):
    def f(t):
        env = math.exp(-decay * t)
        return amp * env * (math.sin(2 * math.pi * freq * t)
                            + 0.35 * math.sin(4 * math.pi * freq * t)
                            + 0.15 * math.sin(6 * math.pi * freq * t))
    return f


def kick():
    def f(t):
        freq = 46 + 105 * math.exp(-28 * t)
        env = math.exp(-13 * t)
        return 0.34 * env * math.sin(2 * math.pi * freq * t)
    return f


def noise(amp, dur, decay=18.0, bright=False):
    def f(t):
        env = math.exp(-decay * t)
        n = random.uniform(-1, 1)
        return amp * env * n
    return f


def riser(dur=0.62):
    def f(t):
        p = t / dur
        env = (p ** 1.6) * (1 - p) * 4
        n = random.uniform(-1, 1)
        tone = math.sin(2 * math.pi * (180 + 900 * p) * t)
        return 0.085 * env * n + 0.05 * env * tone
    return f


def impact():
    def f(t):
        freq = 62 - 26 * min(1.0, t / 0.25)
        return 0.32 * math.exp(-9 * t) * math.sin(2 * math.pi * freq * t)
    return f


# Chord progression: Am - F - C - G, one bar (2 s) each.
ROOTS = [110.00, 87.31, 130.81, 98.00]          # A2 F2 C3 G2
CHORDS = [
    [220.00, 261.63, 329.63],                   # Am
    [174.61, 220.00, 261.63],                   # F
    [261.63, 329.63, 392.00],                   # C
    [196.00, 246.94, 293.66],                   # G
]
BEAT = 0.5
BAR = 4 * BEAT

bar_count = int(math.ceil(LENGTH / BAR))
for b in range(bar_count):
    t0 = b * BAR
    idx = b % 4
    root, chord = ROOTS[idx], CHORDS[idx]
    # warm pad + sub
    for k, f in enumerate(chord):
        add(music, t0, BAR, sine(f, 0.030, BAR, attack=0.25, release=0.5, phase=k * 1.7))
    add(music, t0, BAR, sine(root / 2, 0.045, BAR, attack=0.2, release=0.5))
    for beat in range(4):
        t = t0 + beat * BEAT
        # four-on-the-floor kick
        add(music, t, 0.30, kick())
        # bass pluck
        add(music, t, 0.40, pluck(root, 0.15, 0.40, decay=8.0))
        # clap on 2 and 4
        if beat % 2 == 1:
            add(music, t, 0.16, noise(0.14, 0.16, decay=16.0))
            add(music, t, 0.10, sine(190, 0.035, 0.10, attack=0.001))
        # hats + arp on 8ths
        for eighth in range(2):
            th = t + eighth * 0.25
            add(music, th, 0.05, noise(0.030 if eighth == 0 else 0.020, 0.05, decay=55.0))
            note = chord[(beat * 2 + eighth) % 3] * 2
            add(music, th, 0.18, pluck(note, 0.038, 0.18, decay=16.0))

# Scene impacts and transition risers.
for t in (0.0, 5.0, 12.0, 16.0, 20.0, 25.0, 31.0, 37.0):
    add(music, t, 0.45, impact())
    add(music, t, 0.22, noise(0.10, 0.22, decay=14.0))
for t in (4.55, 11.55, 24.55, 36.55):
    add(music, t, 0.62, riser())

# End signature: bright shimmering chord and a final hit.
for i, f in enumerate([440.0, 554.37, 659.25, 880.0]):
    add(music, 42.7, 2.6, sine(f, 0.055, 2.6, attack=0.06, release=1.4, phase=i))
    add(music, 43.1 + i * 0.12, 0.9, pluck(f * 2, 0.045, 0.9, decay=4.0))
add(music, 44.4, 0.9, impact())

print(f"  music bed synthesized ({N} samples @ {SR} Hz)")


# ---------------------------------------------------------------------------
# 3. Mix voiceover with ducking
# ---------------------------------------------------------------------------
clips = prepare_vo()
vo = [0.0] * N
duck = [1.0] * N

for name, start, samples in clips:
    i0 = int(start * SR)
    for j, v in enumerate(samples):
        if i0 + j < N:
            vo[i0 + j] += v
    end = start + len(samples) / SR
    # smooth duck: down 0.15 s before, up 0.25 s after
    a, b, c, d = start - 0.18, start + 0.06, end + 0.04, end + 0.28
    for i in range(max(0, int(a * SR)), min(N, int(d * SR))):
        t = i / SR
        if t < a: k = 1.0
        elif t < b:
            p = (t - a) / (b - a); k = 1 - 0.55 * (p * p * (3 - 2 * p))
        elif t < c: k = 0.45
        elif t < d:
            p = (t - c) / (d - c); k = 0.45 + 0.55 * (p * p * (3 - 2 * p))
        else: k = 1.0
        duck[i] = min(duck[i], k)

out = [music[i] * duck[i] * 0.72 + vo[i] for i in range(N)]
peak = max(abs(v) for v in out) or 1.0
gain = 0.94 / peak if peak > 0.94 else 1.0
pcm = array("h", (int(max(-1.0, min(1.0, v * gain)) * 32767) for v in out))

with wave.open(str(OUT), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())

print(f"  wrote {OUT}  ({N/SR:.2f}s, peak {peak:.3f}, gain {gain:.3f})")
