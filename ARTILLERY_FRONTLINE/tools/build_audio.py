#!/usr/bin/env python3
"""Synthesize the game's sound effects. Every clip is generated from
oscillators and filtered noise; nothing is sampled or downloaded.

    python3 tools/build_audio.py            the zombie-siege clips
    python3 tools/build_audio.py --base     also re-render the base set (slow: pure Python)

Requires numpy and scipy. Output: assets/audio/*.wav (24 kHz, mono, 16-bit).
"""
import os
import sys
import wave

import numpy as np
from scipy import signal

RATE = 24000
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(PROJECT, "assets", "audio")


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def noise(seconds, seed):
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(RATE * seconds))


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, RATE * 0.49) / (RATE / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (RATE / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, low, high, order=2):
    b, a = signal.butter(order, [low / (RATE / 2), min(high, RATE * 0.49) / (RATE / 2)], "band")
    return signal.lfilter(b, a, x)


def sweep(seconds, start, end, shape="sine", curve=1.0):
    """Oscillator gliding from `start` to `end` Hz."""
    x = t(seconds)
    frac = (x / seconds) ** curve
    freq = start + (end - start) * frac
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if shape == "saw":
        return 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0
    if shape == "square":
        return np.sign(np.sin(phase))
    return np.sin(phase)


def decay(seconds, rate, attack=0.002):
    x = t(seconds)
    return np.minimum(x / attack, 1.0) * np.exp(-x * rate)


def envelope(seconds, attack, release, hold=1.0):
    x = t(seconds)
    up = np.clip(x / attack, 0.0, 1.0)
    down = np.clip((seconds - x) / release, 0.0, 1.0)
    return up * down * hold


def fit(x, seconds):
    n = int(RATE * seconds)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def place(base, clip, at):
    start = int(at * RATE)
    end = min(len(base), start + len(clip))
    base[start:end] += clip[:end - start]
    return base


def write(name, samples, peak=0.92):
    samples = np.asarray(samples, np.float64)
    samples = samples - samples.mean()
    top = np.abs(samples).max()
    if top > 0:
        samples = samples / top * peak
    # Short fades stop clicks at both ends.
    fade = min(len(samples) // 2, int(RATE * 0.004))
    samples[:fade] *= np.linspace(0.0, 1.0, fade)
    samples[-fade:] *= np.linspace(1.0, 0.0, fade)
    data = np.round(samples * 32767.0).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())
    print("audio %-18s %.2fs" % (name, len(samples) / RATE))


def hmg_shot():
    seconds = 0.3
    crack = highpass(noise(seconds, 1), 900) * decay(seconds, 46)
    body = lowpass(noise(seconds, 2), 1400) * decay(seconds, 20)
    thump = sweep(seconds, 150, 48) * decay(seconds, 17)
    clack = bandpass(noise(seconds, 3), 2200, 5200) * decay(seconds, 90) * 0.5
    tail = lowpass(noise(seconds, 4), 500) * decay(seconds, 7) * 0.35
    write("hmg_shot", np.tanh((crack * 0.9 + body * 1.2 + thump * 1.4 + clack + tail) * 1.8))


def dry_fire():
    seconds = 0.09
    write("dry_fire", bandpass(noise(seconds, 5), 1800, 6000) * decay(seconds, 80) + sweep(seconds, 2600, 2300) * decay(seconds, 110) * 0.5, 0.6)


def headshot():
    seconds = 0.3
    pop = sweep(seconds, 320, 70) * decay(seconds, 22)
    wet = lowpass(noise(seconds, 6), 2600) * decay(seconds, 26)
    crack = bandpass(noise(seconds, 7), 1500, 4500) * decay(seconds, 70) * 0.6
    write("headshot", pop + wet * 0.9 + crack, 0.85)


def voice(seconds, start, end, seed, rough=0.5, formants=((480, 900), (1000, 1700)), breath=0.25):
    """A throat: a sagging sawtooth through two formant bands, with growl."""
    rng = np.random.default_rng(seed)
    x = t(seconds)
    wobble = 1.0 + 0.045 * np.sin(2 * np.pi * rng.uniform(4.5, 7.0) * x) + 0.03 * lowpass(noise(seconds, seed + 1), 12) * 6.0
    frac = x / seconds
    freq = (start + (end - start) * frac) * wobble
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    source = 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0
    growl = 1.0 - rough * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rng.uniform(24, 38) * x + lowpass(noise(seconds, seed + 2), 20) * 30.0)))
    source = source * growl
    out = np.zeros_like(source)
    for low, high in formants:
        out += bandpass(source, low, high)
    out += bandpass(noise(seconds, seed + 3), 900, 3200) * breath * (0.4 + 0.6 * np.abs(lowpass(noise(seconds, seed + 4), 9)) * 5.0)
    return out


def zombies():
    write("zombie_groan_1", voice(1.5, 92, 70, 11) * envelope(1.5, 0.22, 0.6), 0.8)
    write("zombie_groan_2", voice(1.2, 118, 84, 21, 0.6, ((380, 760), (900, 1500))) * envelope(1.2, 0.15, 0.5), 0.8)
    write("zombie_groan_3", voice(1.7, 76, 64, 31, 0.7, ((560, 980), (1200, 2000)), 0.35) * envelope(1.7, 0.3, 0.7), 0.8)
    write("zombie_attack_1", voice(0.62, 150, 212, 41, 0.8, ((600, 1200), (1500, 2600)), 0.5) * envelope(0.62, 0.05, 0.25), 0.85)
    write("zombie_attack_2", voice(0.5, 178, 132, 51, 0.85, ((520, 1100), (1700, 2900)), 0.55) * envelope(0.5, 0.04, 0.22), 0.85)
    for index, (start, end, seed) in enumerate(((170, 58, 61), (132, 52, 71))):
        seconds = 0.95
        cry = voice(seconds, start, end, seed, 0.75, ((450, 900), (1100, 1900)), 0.45) * envelope(seconds, 0.03, 0.55)
        thud = fit(sweep(0.25, 95, 40) * decay(0.25, 16) + lowpass(noise(0.25, seed + 9), 500) * decay(0.25, 20), seconds - 0.62)
        write("zombie_death_%d" % (index + 1), place(cry, thud * 1.4, 0.62), 0.85)


def clang(seconds, partials, seed, ring=7.0):
    x = t(seconds)
    rng = np.random.default_rng(seed)
    out = np.zeros_like(x)
    for index, freq in enumerate(partials):
        out += np.sin(2 * np.pi * freq * x + rng.uniform(0, 6.28)) * np.exp(-x * (ring + index * 2.6)) / (1.0 + index * 0.35)
    strike = bandpass(noise(seconds, seed + 1), 700, 5200) * decay(seconds, 70)
    boom = sweep(seconds, 110, 50) * decay(seconds, 14)
    return out + strike * 1.1 + boom * 1.3


def defenses():
    write("gate_hit_1", clang(0.6, (182, 431, 673, 1127, 1721, 2390), 81), 0.9)
    write("gate_hit_2", clang(0.55, (164, 388, 742, 1009, 1558, 2212), 91, 8.5), 0.9)
    for index, seed in enumerate((101, 111)):
        seconds = 0.4
        thud = sweep(seconds, 96 - index * 14, 42) * decay(seconds, 18)
        scrape = bandpass(noise(seconds, seed), 500, 2400) * decay(seconds, 16) * (0.6 + 0.4 * np.abs(lowpass(noise(seconds, seed + 1), 40)) * 3)
        grit = highpass(noise(seconds, seed + 2), 3000) * decay(seconds, 45) * 0.3
        write("wall_hit_%d" % (index + 1), thud * 1.5 + scrape + grit, 0.85)
    seconds = 1.9
    crash = np.zeros(int(RATE * seconds))
    for index, at in enumerate((0.0, 0.07, 0.19, 0.36, 0.6)):
        place(crash, clang(0.9, (150 + index * 23, 367 + index * 31, 598, 1040 + index * 60, 1630), 121 + index, 5.0) / (1.0 + index * 0.4), at)
    rumble = lowpass(noise(seconds, 131), 320) * decay(seconds, 2.6, 0.01) * 2.4
    debris = highpass(noise(seconds, 132), 2500) * decay(seconds, 3.5) * (np.abs(lowpass(noise(seconds, 133), 30)) * 4.0) * 0.5
    write("gate_break", np.tanh((crash + rumble + debris) * 0.9), 0.95)
    seconds = 2.3
    boom = sweep(seconds, 70, 28) * decay(seconds, 3.2, 0.005) * 2.2
    rock = lowpass(noise(seconds, 141), 900) * decay(seconds, 2.2, 0.01) * (0.5 + np.abs(lowpass(noise(seconds, 142), 18)) * 5.0)
    crack = bandpass(noise(seconds, 143), 1200, 5000) * decay(seconds, 9) * 0.8
    pebbles = highpass(noise(seconds, 144), 3500) * np.clip(lowpass(noise(seconds, 145), 25) * 8.0, 0, 1) * decay(seconds, 1.6) * 0.35
    write("wall_break", np.tanh((boom + rock + crack + pebbles) * 0.9), 0.95)


def signals():
    seconds = 2.6
    x = t(seconds)
    cycle = (x % 1.3) / 1.3
    freq = 480 + 420 * np.sin(np.pi * cycle) ** 1.2
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    siren = lowpass(np.sign(np.sin(phase)) * 0.6 + np.sin(phase), 2600) * envelope(seconds, 0.05, 0.3)
    write("alarm", siren, 0.75)
    seconds = 2.0
    horn = np.zeros(int(RATE * seconds))
    for freq, gain in ((87.3, 1.0), (130.8, 0.7), (174.6, 0.45)):
        horn += sweep(seconds, freq * 0.97, freq, "saw", 0.3) * gain
    horn = lowpass(horn, 900) * envelope(seconds, 0.35, 0.7) * (1.0 + 0.05 * np.sin(2 * np.pi * 5.2 * t(seconds)))
    write("wave_horn", horn, 0.8)
    seconds = 1.4
    chime = np.zeros(int(RATE * seconds))
    for index, freq in enumerate((392.0, 493.9, 587.3, 784.0)):
        note = (np.sin(2 * np.pi * freq * t(0.9)) + 0.35 * np.sin(2 * np.pi * freq * 2.0 * t(0.9))) * decay(0.9, 5.5, 0.004)
        place(chime, note, index * 0.11)
    write("wave_clear", chime, 0.7)


def base_set():
    """The simple per-sample clips carried over from the first sound pass:
    interface click, impacts, explosion, reload, wind bed and the music loop."""
    import math
    import random
    import struct

    def render(name, duration, fn):
        rng = random.Random(421)
        values = []
        low = 0.0
        low2 = 0.0
        for i in range(int(RATE * duration)):
            x = i / RATE
            n = rng.uniform(-1, 1)
            low = 0.94 * low + 0.06 * n
            low2 = 0.995 * low2 + 0.005 * n
            values.append(fn(x, n, low, low2))
        peak = max(0.01, max(abs(v) for v in values))
        gain = 0.78 / peak
        with wave.open(os.path.join(OUT, name + ".wav"), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(RATE)
            handle.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * gain)) * 32767)) for v in values))
        print("audio %-18s %.2fs" % (name, duration))

    sin, exp, pi = math.sin, math.exp, math.pi
    render("explosion", 2.8, lambda x, n, l, l2: (l2 * 5 + l * 0.8) * exp(-x * 1.8) + sin(2 * pi * 38 * x) * 0.4 * exp(-x * 3) + n * 0.22 * exp(-x * 12))
    render("reload", 0.8, lambda x, n, l, l2: sum(exp(-max(0, x - a) * 35) * (sin(2 * pi * f * x) * 0.3 + n * 0.2)
                                                 for a, f in [(0, 430), (0.24, 720), (0.53, 240)] if x >= a))
    render("click", 0.09, lambda x, n, l, l2: sin(2 * pi * 880 * x) * exp(-x * 55) * 0.4)
    render("impact", 0.65, lambda x, n, l, l2: n * 0.4 * exp(-x * 18) + sin(2 * pi * 110 * x) * exp(-x * 9) * 0.35)
    render("wind", 8.0, lambda x, n, l, l2: (l * 0.7 + l2 * 1.5) * (0.6 + 0.15 * sin(2 * pi * x / 8)))
    render("impact_flesh", 0.32, lambda x, n, l, l2: l * 0.9 * exp(-x * 30) + sin(2 * pi * (70 * x - 15 * x * x)) * 0.5 * exp(-x * 14) + n * 0.12 * exp(-x * 45))
    render("impact_metal", 0.9, lambda x, n, l, l2: sum(a * sin(2 * pi * f * x) * exp(-x * d) for f, a, d in [(1180, 0.5, 7), (1870, 0.35, 9), (2760, 0.22, 12)])
           + n * 0.35 * exp(-x * 60))
    render("critical", 0.7, lambda x, n, l, l2: sum(a * sin(2 * pi * f * x) * exp(-x * d) for f, a, d in [(1320, 0.45, 6), (1980, 0.3, 8), (2640, 0.18, 11)])
           + n * 0.08 * exp(-x * 90))
    # The music loop uses integer frequencies only, so it repeats exactly at its length.
    chords = [(55, 110, 165, 220), (44, 88, 132, 176), (49, 98, 147, 196), (41, 82, 123, 164)]

    def theme(x, n, l, l2):
        chord = chords[int(x // 12) % 4]
        pad = sum(sin(2 * pi * f * x) for f in chord) * 0.05 * (0.75 + 0.25 * sin(2 * pi * x / 6))
        bass = sin(2 * pi * chord[0] * x) * 0.22 * exp(-(x % 0.75) * 6)
        kick = sin(2 * pi * 48 * (x % 1.5)) * 0.5 * exp(-(x % 1.5) * 9)
        hat = n * 0.07 * exp(-(x % 0.375) * 60)
        return pad + bass + kick + hat

    render("music_theme", 48.0, theme)


def main():
    if "--base" in sys.argv:
        base_set()
    hmg_shot()
    dry_fire()
    headshot()
    zombies()
    defenses()
    signals()


if __name__ == "__main__":
    main()
