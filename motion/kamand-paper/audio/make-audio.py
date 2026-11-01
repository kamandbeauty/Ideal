#!/usr/bin/env python3
"""Build the 30 s audio bed for the KAMAND paper kinetic reel.

Reuses five Persian voiceover clips generated for `kamand-eye` (fallback TTS),
time-stretches them, schedules them to the six visual beats, synthesizes a
clean 120 BPM electronic bed, and mixes to `mix.wav`.

Usage: python3 motion/kamand-paper/audio/make-audio.py
"""
import math
import os
import random
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
FALLBACK = HERE.parent.parent / "kamand-eye" / "audio" / "vo"

SR = 24000
LENGTH = 30.5
N = int(LENGTH * SR)

# (filename in kamand-eye VO library, our filename, start second, atempo)
SCHEDULE = [
    ("01-hook.wav",    "01-hook.wav",    0.35, 1.12),
    ("03-giahi.wav",   "02-giahi.wav",  10.30, 1.12),
    ("04-sefidak.wav", "03-sefidak.wav", 15.30, 1.12),
    ("05-rizesh.wav",  "04-rizesh.wav",  18.20, 1.12),
    ("10-final.wav",   "05-final.wav",  25.00, 1.12),
]


def prepare_vo():
    VO.mkdir(parents=True, exist_ok=True)
    TIMED.mkdir(parents=True, exist_ok=True)
    clips = []
    for src_name, name, start, tempo in SCHEDULE:
        src = FALLBACK / src_name
        if not src.exists():
            raise SystemExit(f"Missing fallback VO clip: {src}")
        # keep a local copy so this film is portable
        local = VO / name
        if not local.exists():
            local.write_bytes(src.read_bytes())
        dst = TIMED / name
        subprocess.run(
            [FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", str(local),
             "-filter:a", f"atempo={tempo}", "-ar", str(SR), "-ac", "1", str(dst)],
            check=True,
        )
        with wave.open(str(dst), "rb") as w:
            pcm = array("h"); pcm.frombytes(w.readframes(w.getnframes()))
            samples = [v / 32768.0 for v in pcm]
        clips.append((name, start, samples))
        print(f"  VO {name:16s} at {start:5.2f}s  {len(samples)/SR:.2f}s")
    return clips


random.seed(21)
music = [0.0] * N


def add(buf, start, dur, fn):
    i0, i1 = max(0, int(start * SR)), min(len(buf), int((start + dur) * SR))
    for i in range(i0, i1):
        buf[i] += fn((i - i0) / SR)


def sine(freq, amp, dur, attack=0.004, release=None, phase=0.0):
    release = release if release is not None else dur * 0.8
    def f(t):
        env = min(1.0, t / attack) if attack else 1.0
        if t > dur - release:
            env *= max(0.0, (dur - t) / release)
        return amp * env * math.sin(2 * math.pi * freq * t + phase)
    return f


def pluck(freq, amp, dur, decay=8.0):
    def f(t):
        e = math.exp(-decay * t)
        return amp * e * (math.sin(2*math.pi*freq*t) + .3*math.sin(4*math.pi*freq*t) + .12*math.sin(6*math.pi*freq*t))
    return f


def kick():
    def f(t):
        freq = 48 + 100 * math.exp(-28 * t)
        return .30 * math.exp(-13 * t) * math.sin(2 * math.pi * freq * t)
    return f


def noise(amp, dur, decay=18.0):
    return lambda t: amp * math.exp(-decay * t) * random.uniform(-1, 1)


def riser(dur=.55):
    def f(t):
        p = t / dur
        e = (p ** 1.6) * (1 - p) * 4
        return .07 * e * random.uniform(-1, 1) + .045 * e * math.sin(2*math.pi*(200+800*p)*t)
    return f


ROOTS = [110.00, 87.31, 130.81, 98.00]
CHORDS = [[220.00, 261.63, 329.63], [174.61, 220.00, 261.63],
          [261.63, 329.63, 392.00], [196.00, 246.94, 293.66]]
BEAT, BAR = 0.5, 2.0
for b in range(int(math.ceil(LENGTH / BAR))):
    t0 = b * BAR
    idx = b % 4
    root, chord = ROOTS[idx], CHORDS[idx]
    for k, f in enumerate(chord):
        add(music, t0, BAR, sine(f, .026, BAR, attack=.22, release=.5, phase=k*1.7))
    add(music, t0, BAR, sine(root/2, .04, BAR, attack=.2, release=.5))
    for beat in range(4):
        t = t0 + beat * BEAT
        add(music, t, .3, kick())
        add(music, t, .4, pluck(root, .13, .4, decay=8))
        if beat % 2 == 1:
            add(music, t, .16, noise(.12, .16, 16))
        for eighth in range(2):
            th = t + eighth * .25
            add(music, th, .05, noise(.026 if eighth == 0 else .018, .05, 55))
            add(music, th, .18, pluck(chord[(beat*2+eighth) % 3]*2, .032, .18, 16))

for t in (0.0, 5.0, 10.0, 15.0, 20.0, 25.0):
    add(music, t, .4, lambda s: .28*math.exp(-9*s)*math.sin(2*math.pi*(60-24*min(1,s/.25))*s))
    add(music, t, .2, noise(.09, .2, 14))
for t in (4.6, 9.6, 14.6, 19.6, 24.6):
    add(music, t, .55, riser())
for i, f in enumerate([440.0, 554.37, 659.25, 880.0]):
    add(music, 28.4, 2.0, sine(f, .05, 2.0, attack=.05, release=1.1, phase=i))
add(music, 29.5, .8, kick())

print(f"  music bed synthesized ({N} samples @ {SR} Hz)")

clips = prepare_vo()
vo = [0.0] * N
duck = [1.0] * N
for name, start, samples in clips:
    i0 = int(start * SR)
    for j, v in enumerate(samples):
        if i0 + j < N:
            vo[i0 + j] += v
    end = start + len(samples) / SR
    a, b, c, d = start-.18, start+.06, end+.04, end+.28
    for i in range(max(0, int(a*SR)), min(N, int(d*SR))):
        t = i / SR
        if t < a: k = 1.0
        elif t < b:
            p=(t-a)/(b-a); k=1-.55*(p*p*(3-2*p))
        elif t < c: k = .45
        elif t < d:
            p=(t-c)/(d-c); k=.45+.55*(p*p*(3-2*p))
        else: k = 1.0
        duck[i] = min(duck[i], k)

out = [music[i]*duck[i]*.72 + vo[i] for i in range(N)]
peak = max(abs(v) for v in out) or 1.0
gain = .94/peak if peak > .94 else 1.0
pcm = array("h", (int(max(-1, min(1, v*gain))*32767) for v in out))
with wave.open(str(OUT), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print(f"  wrote {OUT} ({N/SR:.2f}s, peak {peak:.3f})")
