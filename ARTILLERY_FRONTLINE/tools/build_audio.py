#!/usr/bin/env python3
"""Synthesize the game's sound effects. Every clip is generated from
oscillators and filtered noise; nothing is sampled or downloaded.

    python3 tools/build_audio.py                 the siege clips: guns, explosives, zombies, wall, signals, interface
    python3 tools/build_audio.py --base          also re-render the base set (slow: pure Python)
    python3 tools/build_audio.py --only=a,b      only these groups (see GROUPS at the end of the file)
    python3 tools/build_audio.py --check         measure every clip on disk instead of writing any

Requires numpy and scipy. Output: assets/audio/*.wav (24 kHz, mono, 16-bit).
The generator is seeded: the same source gives the same files, byte for byte.
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


def metal_ping(seconds, freqs, seed, ring=40.0):
    """A short mechanical strike: inharmonic partials plus a noise transient."""
    x = t(seconds)
    rng = np.random.default_rng(seed)
    out = np.zeros_like(x)
    for index, freq in enumerate(freqs):
        out += np.sin(2 * np.pi * freq * x + rng.uniform(0, 6.28)) * np.exp(-x * (ring + index * 8.0)) / (1.0 + index * 0.4)
    out += bandpass(noise(seconds, seed + 1), 1800, 7000) * decay(seconds, 90, 0.0004) * 0.7
    return out


def hmg_shot():
    """A heavy mounted gun: tight crack, chest thump, bolt, short street tail."""
    seconds = 0.34
    crack = highpass(noise(seconds, 1), 2200) * decay(seconds, 95, 0.00035)
    snap = bandpass(noise(seconds, 11), 700, 2800) * decay(seconds, 55, 0.0005)
    body = bandpass(noise(seconds, 2), 140, 1400) * decay(seconds, 16, 0.0012)
    thump = sweep(seconds, 108, 32, curve=0.5) * decay(seconds, 12, 0.0007)
    thump += sweep(seconds, 58, 24) * decay(seconds, 9, 0.001) * 0.7
    bolt = metal_ping(seconds, (1840, 2650, 4120, 6300), 3, 55.0) * 0.55
    room = lowpass(noise(seconds, 4), 620) * decay(seconds, 5.5, 0.01) * 0.42
    write("hmg_shot", np.tanh((crack * 1.35 + snap * 1.1 + body * 1.45 + thump * 1.9 + bolt + room) * 1.55))


def hmg_tail():
    """What is left of a burst once the trigger is released: the report rolling off the house fronts."""
    seconds = 1.15
    x = t(seconds)
    roll = lowpass(noise(seconds, 421), 900) * decay(seconds, 3.6, 0.01)
    low = lowpass(noise(seconds, 422), 240) * decay(seconds, 2.4, 0.025) * 1.5
    slaps = np.zeros_like(x)
    for index, (at, gain) in enumerate(((0.07, 0.62), (0.18, 0.4), (0.34, 0.24), (0.52, 0.14))):
        place(slaps, bandpass(noise(0.18, 423 + index), 400, 2200) * decay(0.18, 22, 0.003) * gain, at)
    write("hmg_tail", np.tanh((roll + low + slaps) * 1.15), 0.62)


def rotary_gun():
    """The six-barrel gun. At twenty-five rounds a second single shots run together, so the clip the game
    repeats holds two reports, 40 ms apart, over the whine of the drive. Its spin-up and its run-down are
    clips of their own."""
    seconds = 0.24
    shots = np.zeros(int(RATE * seconds))
    for index, at in enumerate((0.0, 0.038)):
        length = 0.16
        crack = highpass(noise(length, 501 + index), 2400) * decay(length, 110, 0.0003)
        body = bandpass(noise(length, 503 + index), 220, 1600) * decay(length, 38, 0.0008)
        thump = sweep(length, 210, 62, curve=0.55) * decay(length, 28, 0.0006)
        ping = metal_ping(length, (2100, 3400, 5100), 505 + index, 70.0) * 0.35
        place(shots, crack * 1.2 + body * 1.15 + thump * 1.1 + ping, at)
    whine = lowpass(sweep(seconds, 680, 640, "saw"), 2800) * envelope(seconds, 0.003, 0.1) * 0.12
    tail = lowpass(noise(seconds, 507), 580) * decay(seconds, 8) * 0.22
    write("rotary_shot", np.tanh((shots + whine + tail) * 1.65))
    # The motor climbing to speed before the first round goes.
    seconds = 0.44
    climb = lowpass(sweep(seconds, 70, 740, "saw", 0.65), 2600) * envelope(seconds, 0.025, 0.07)
    gear = bandpass(noise(seconds, 508), 800, 3800) * envelope(seconds, 0.04, 0.08) * (t(seconds) / seconds) * 0.32
    ticks = np.zeros(int(RATE * seconds))
    for index in range(7):
        place(ticks, metal_ping(0.05, (900 + index * 40, 1800), 520 + index, 80.0) * (0.15 + 0.08 * index), index * 0.055)
    write("rotary_spin", climb * 0.7 + gear + ticks * 0.45, 0.5)
    # The barrels coasting to a stop while the report rolls off the house fronts.
    seconds = 1.2
    fall = lowpass(sweep(seconds, 600, 70, "saw", 0.6), 2000) * decay(seconds, 2.6, 0.01) * 0.5
    roll = lowpass(noise(seconds, 509), 1000) * decay(seconds, 4.5, 0.012)
    low = lowpass(noise(seconds, 510), 300) * decay(seconds, 3.2, 0.03)
    write("rotary_tail", fall + roll * 0.9 + low, 0.6)


def dry_fire():
    seconds = 0.11
    click = metal_ping(seconds, (2100, 3400, 5100), 5, 90.0)
    hollow = sweep(seconds, 420, 280) * decay(seconds, 70, 0.0005) * 0.45
    write("dry_fire", click * 0.9 + hollow, 0.62)


def headshot():
    seconds = 0.32
    pop = sweep(seconds, 280, 52, curve=0.45) * decay(seconds, 18, 0.0006)
    wet = lowpass(noise(seconds, 6), 1800) * decay(seconds, 20, 0.001)
    crack = highpass(noise(seconds, 7), 2200) * decay(seconds, 80, 0.0004) * 0.7
    bone = metal_ping(seconds, (980, 1620, 2400), 8, 28.0) * 0.4
    write("headshot", np.tanh((pop * 1.3 + wet * 1.1 + crack + bone) * 1.4), 0.88)


def mechanics():
    """Reload, click, and the three kinds of strike: paving, flesh, metal."""
    seconds = 0.82
    belt = np.zeros(int(RATE * seconds))
    place(belt, metal_ping(0.16, (420, 880, 1540), 601, 28.0) * 0.8, 0.0)
    place(belt, metal_ping(0.12, (980, 1760, 2650), 602, 40.0) * 0.7, 0.22)
    place(belt, bandpass(noise(0.18, 603), 200, 900) * envelope(0.18, 0.02, 0.08) * 0.5, 0.38)
    place(belt, metal_ping(0.22, (310, 640, 1100, 1880), 604, 18.0) * 1.1, 0.52)
    write("reload", np.tanh(belt * 1.3), 0.78)
    seconds = 0.08
    tick = metal_ping(seconds, (1320, 1980, 3100), 401, 100.0)
    write("click", tick, 0.68)
    seconds = 0.7
    thud = sweep(seconds, 92, 36, curve=0.5) * decay(seconds, 10, 0.003) * 1.5
    grit = bandpass(noise(seconds, 701), 400, 2200) * decay(seconds, 14, 0.002)
    stone = highpass(noise(seconds, 702), 2800) * decay(seconds, 40) * 0.35
    write("impact", np.tanh((thud + grit + stone) * 1.2), 0.86)
    seconds = 0.34
    wet = lowpass(noise(seconds, 711), 1400) * decay(seconds, 22, 0.001) * 1.3
    slap = sweep(seconds, 78, 28) * decay(seconds, 16, 0.0008)
    drip = bandpass(noise(seconds, 712), 900, 2800) * decay(seconds, 36) * 0.45
    write("impact_flesh", np.tanh((wet + slap * 1.2 + drip) * 1.25), 0.84)
    seconds = 0.85
    ring = metal_ping(seconds, (1180, 1870, 2760, 3920, 5100), 721, 9.0)
    boom = sweep(seconds, 140, 48) * decay(seconds, 11, 0.002)
    write("impact_metal", np.tanh((ring * 1.2 + boom * 0.9) * 1.15), 0.88)
    seconds = 0.72
    warn = metal_ping(seconds, (1320, 1980, 2640), 731, 8.0)
    pulse = sweep(seconds, 220, 90) * decay(seconds, 7, 0.004) * 0.8
    write("critical", np.tanh((warn + pulse) * 1.1), 0.8)


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


def giants():
    """The boss: a roar that rolls down the street when it appears, and the long fall when it dies."""
    seconds = 2.6
    x = t(seconds)
    swell = np.minimum(x / 0.35, 1.0) * np.clip((seconds - x) / 0.9, 0.0, 1.0)
    throat = voice(seconds, 78, 46, 301, 0.85, ((260, 620), (700, 1400)), 0.3)
    chest = lowpass(voice(seconds, 39, 27, 311, 0.9, ((90, 260), (300, 560)), 0.1), 420) * 1.6
    rasp = bandpass(noise(seconds, 321), 1400, 3600) * (0.5 + 0.5 * np.abs(lowpass(noise(seconds, 322), 7)) * 5.0) * 0.25
    echo = np.zeros_like(x)
    place(echo, (throat + chest)[:int(RATE * (seconds - 0.19))] * 0.3, 0.19)
    write("boss_roar", np.tanh((throat + chest + rasp + echo) * swell * 1.3), 0.95)
    seconds = 2.9
    x = t(seconds)
    cry = voice(seconds, 96, 30, 331, 0.85, ((240, 600), (680, 1300)), 0.35) * np.minimum(x / 0.06, 1.0) * np.clip((1.9 - x) / 1.2, 0.0, 1.0)
    under = lowpass(voice(seconds, 44, 22, 341, 0.9, ((80, 240), (280, 520)), 0.1), 380) * 1.5 * np.clip((2.0 - x) / 1.4, 0.0, 1.0)
    fall = np.zeros_like(x)
    place(fall, (sweep(0.9, 70, 26) * decay(0.9, 5.0, 0.004) * 2.4 + lowpass(noise(0.9, 351), 300) * decay(0.9, 6.0, 0.01) * 2.0
                 + highpass(noise(0.9, 352), 2400) * decay(0.9, 9.0) * 0.3), 1.85)
    write("boss_death", np.tanh((cry + under + fall) * 1.2), 0.95)


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


def blast(seconds, seed, weight=1.0, crack_rate=22.0):
    """An explosion: the crack of the charge, a falling boom, rolling rumble and the patter of debris."""
    crack = highpass(noise(seconds, seed), 1600) * decay(seconds, crack_rate, 0.0006)
    body = bandpass(noise(seconds, seed + 1), 80, 1200) * decay(seconds, 6.2 / weight, 0.0015)
    boom = sweep(seconds, 84.0 / weight, 24.0, curve=0.5) * decay(seconds, 2.8 / weight, 0.003)
    boom += sweep(seconds, 48.0 / weight, 18.0) * decay(seconds, 2.2 / weight, 0.004) * 0.8
    rumble = lowpass(noise(seconds, seed + 2), 220) * decay(seconds, 1.8 / weight, 0.018) * (0.6 + np.abs(lowpass(noise(seconds, seed + 3), 12)) * 5.0)
    patter = highpass(noise(seconds, seed + 4), 2600) * np.clip(lowpass(noise(seconds, seed + 5), 28) * 9.0, 0.0, 1.0) \
        * envelope(seconds, 0.1, seconds * 0.8) * 0.28
    return np.tanh((crack * 1.5 + body * 1.6 + boom * 2.6 * weight + rumble * 1.7 + patter) * 1.45)


def explosives():
    write("explosion", blast(2.6, 201, 1.0), 0.97)
    write("explosion_small", blast(1.7, 211, 0.72, 30.0), 0.95)
    # Rocket leaving the tube: the pop of the booster, then the motor tearing away down the street.
    seconds = 1.25
    x = t(seconds)
    pop = highpass(noise(seconds, 221), 900) * decay(seconds, 42, 0.0006) * 1.3
    pop += lowpass(noise(seconds, 221), 1800) * decay(seconds, 28, 0.001) * 1.4
    pop += sweep(seconds, 160, 42, curve=0.5) * decay(seconds, 12, 0.0008) * 1.6
    centre = 2600.0 * np.exp(-x * 2.4) + 420.0
    roar = np.zeros_like(x)
    hiss = noise(seconds, 222)
    for low, high, gain in ((300, 900, 1.0), (900, 2400, 0.8), (2400, 6000, 0.5)):
        band = bandpass(hiss, low, high)
        roar += band * gain * np.exp(-((np.log(centre) - np.log((low * high) ** 0.5)) ** 2) * 1.4)
    roar *= np.minimum(x / 0.03, 1.0) * np.exp(-x * 3.1) * (1.0 + 0.25 * np.sin(2 * np.pi * 47 * x))
    write("rocket", np.tanh((pop + roar * 2.6) * 1.4), 0.9)
    # Grenade leaving the hand: a sleeve of air and the ping of the lever flying off.
    seconds = 0.34
    x = t(seconds)
    air = bandpass(noise(seconds, 231), 500, 2600) * np.sin(np.pi * np.clip(x / 0.26, 0.0, 1.0)) ** 2
    ping = np.sin(2 * np.pi * 3150 * x) * np.exp(-np.clip(x - 0.04, 0.0, None) * 60.0) * (x >= 0.04) * 0.35
    write("grenade_throw", air + ping, 0.6)
    # Cast iron on paving.
    seconds = 0.22
    x = t(seconds)
    clink = sum(np.sin(2 * np.pi * freq * x + index) * np.exp(-x * (38.0 + index * 9.0)) / (1.0 + index * 0.5)
                for index, freq in enumerate((1740, 2890, 4370, 5960)))
    knock = sweep(seconds, 210, 90) * decay(seconds, 45) * 0.9 + bandpass(noise(seconds, 241), 900, 4200) * decay(seconds, 95) * 0.6
    write("grenade_bounce", clink * 0.7 + knock, 0.7)
    # One weapon put away and another brought up: webbing, then metal seating.
    seconds = 0.36
    swap = np.zeros(int(RATE * seconds))
    place(swap, bandpass(noise(0.12, 251), 300, 1800) * envelope(0.12, 0.03, 0.08) * 0.7, 0.0)
    place(swap, bandpass(noise(0.07, 252), 1500, 5200) * decay(0.07, 70) + sweep(0.07, 380, 180) * decay(0.07, 50) * 0.8, 0.17)
    place(swap, bandpass(noise(0.05, 253), 2200, 6000) * decay(0.05, 110) * 0.6, 0.26)
    write("weapon_switch", swap, 0.6)
    # Ammunition handed up: two crate latches and a bright confirmation.
    seconds = 0.75
    crate = np.zeros(int(RATE * seconds))
    for index, at in enumerate((0.0, 0.13)):
        place(crate, clang(0.3, (420 + index * 60, 990, 1730 + index * 110), 261 + index, 22.0) * 0.6, at)
    for index, freq in enumerate((659.3, 987.8)):
        note = (np.sin(2 * np.pi * freq * t(0.42)) + 0.3 * np.sin(2 * np.pi * freq * 2.0 * t(0.42))) * decay(0.42, 8.0, 0.004)
        place(crate, note * 0.55, 0.28 + index * 0.1)
    write("resupply", crate, 0.65)


def bodies():
    """Something heavy coming down on the paving: a brute, or the giant."""
    seconds = 0.55
    thud = sweep(seconds, 88, 34, curve=0.5) * decay(seconds, 11, 0.004) * 1.6
    slap = lowpass(noise(seconds, 411), 700) * decay(seconds, 24, 0.002)
    grit = bandpass(noise(seconds, 412), 900, 3200) * decay(seconds, 40) * 0.45
    write("body_fall", np.tanh((thud + slap + grit) * 1.2), 0.85)


def tone(freq, seconds, partials=(1.0, 0.4, 0.15)):
    x = t(seconds)
    return sum(gain * np.sin(2 * np.pi * freq * (index + 1) * x) for index, gain in enumerate(partials))


def interface():
    """Menu sounds. Short and dry, with enough body under 2 kHz to be heard through a phone speaker."""
    # A switch thrown or a choice made.
    seconds = 0.07
    x = t(seconds)
    tick = np.sin(2 * np.pi * 1320 * x) * np.exp(-x * 90) + 0.5 * np.sin(2 * np.pi * 1980 * x) * np.exp(-x * 120)
    snap = bandpass(noise(seconds, 401), 2500, 7000) * decay(seconds, 220, 0.0005) * 0.5
    write("ui_toggle", tick + snap, 0.7)
    # The order to begin: a drum under two rising notes.
    seconds = 0.5
    begin = np.zeros(int(RATE * seconds))
    place(begin, sweep(0.22, 140, 60) * decay(0.22, 18) * 1.2 + lowpass(noise(0.22, 402), 900) * decay(0.22, 30) * 0.5, 0.0)
    for index, freq in enumerate((392.0, 587.3)):
        place(begin, tone(freq, 0.34) * decay(0.34, 9.0, 0.004) * 0.6, 0.02 + index * 0.1)
    write("ui_start", begin, 0.7)
    # A step back: the same two notes, falling and softer.
    seconds = 0.26
    back = np.zeros(int(RATE * seconds))
    for index, freq in enumerate((587.3, 392.0)):
        place(back, tone(freq, 0.18, (1.0, 0.3)) * decay(0.18, 16.0, 0.003) * 0.6, index * 0.07)
    write("ui_back", back, 0.5)


def horn_note(freq, seconds, release=0.3):
    """A plain brass-like tone: a stack of falling harmonics, slightly detuned against itself."""
    x = t(seconds)
    body = sum(np.sin(2 * np.pi * freq * k * x) / k ** 1.3 for k in range(1, 8))
    body += 0.5 * sum(np.sin(2 * np.pi * freq * 1.004 * k * x + 1.0) / k ** 1.3 for k in range(1, 8))
    return lowpass(body, 2600) * envelope(seconds, 0.035, release) * (1.0 + 0.03 * np.sin(2 * np.pi * 5.0 * x))


def endings():
    """The two stingers of the result screen."""
    # The wall held: three pick-up notes and a long major chord over a drum roll that swells and stops.
    seconds = 3.0
    held = np.zeros(int(RATE * seconds))
    for index, freq in enumerate((196.0, 261.6, 329.6)):
        place(held, horn_note(freq, 0.3, 0.12) * 0.8, index * 0.2)
    for freq, gain in ((261.6, 1.0), (329.6, 0.75), (392.0, 0.7), (523.3, 0.5)):
        place(held, horn_note(freq, 2.3, 1.3) * gain * 0.55, 0.62)
    place(held, sweep(0.5, 110, 46) * decay(0.5, 9.0, 0.004) * 1.6 + lowpass(noise(0.5, 431), 600) * decay(0.5, 14.0) * 0.6, 0.62)
    write("victory", held, 0.8)
    # The wall fell: a slow fall through a minor chord onto a low note that beats against itself and dies away.
    seconds = 3.4
    x = t(seconds)
    fell = np.zeros(int(RATE * seconds))
    for index, freq in enumerate((220.0, 174.6, 146.8)):
        place(fell, horn_note(freq, 0.75, 0.45) * 0.7, index * 0.5)
    low = (np.sin(2 * np.pi * 55.0 * x) + 0.8 * np.sin(2 * np.pi * 55.9 * x) + 0.5 * np.sin(2 * np.pi * 110.0 * x)
           + 0.35 * np.sin(2 * np.pi * 164.8 * x)) * np.clip((x - 1.3) / 0.5, 0.0, 1.0) * np.clip((seconds - x) / 1.5, 0.0, 1.0)
    toll = sweep(0.9, 82, 40) * decay(0.9, 5.0, 0.004) * 1.5 + lowpass(noise(0.9, 441), 400) * decay(0.9, 7.0, 0.01) * 0.8
    place(fell, toll, 1.45)
    write("defeat", fell + low * 0.9, 0.8)


def wind_bed():
    """The wind over the wall, as a loop with no seam: the tail is cross-faded into the head."""
    seconds, overlap = 8.0, 0.6
    raw = np.random.default_rng(451).uniform(-1.0, 1.0, int(RATE * (seconds + overlap)))
    quick = signal.lfilter([0.06], [1.0, -0.94], raw)
    slow = signal.lfilter([0.005], [1.0, -0.995], raw)
    body = quick * 0.7 + slow * 1.5
    count, lap = int(RATE * seconds), int(RATE * overlap)
    loop = body[:count].copy()
    # Equal-power: the two stretches of noise are unrelated.
    blend = np.linspace(0.0, 1.0, lap)
    loop[:lap] = body[:lap] * np.sqrt(blend) + body[count:count + lap] * np.sqrt(1.0 - blend)
    loop *= 0.6 + 0.15 * np.sin(2 * np.pi * t(seconds) / seconds)
    loop -= loop.mean()
    loop = loop / np.abs(loop).max() * 0.78
    with wave.open(os.path.join(OUT, "wind.wav"), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(np.round(loop * 32767.0).astype("<i2").tobytes())
    print("audio %-18s %.2fs (loop)" % ("wind", seconds))


def check():
    """Measures every clip on disk. Nobody can listen in a build machine, so the numbers stand in for ears:
    level, the loudest tenth of a second, where the energy sits, and whether a clip starts or ends on a step."""
    print("%-18s %6s %6s %6s %7s %6s %7s %7s" % ("clip", "sec", "peak", "rms", "loud.1", "centr", "first", "last"))
    for name in sorted(os.listdir(OUT)):
        if not name.endswith(".wav"):
            continue
        with wave.open(os.path.join(OUT, name)) as handle:
            rate = handle.getframerate()
            data = np.frombuffer(handle.readframes(handle.getnframes()), "<i2").astype(np.float64) / 32768.0
        window = int(rate * 0.1)
        if len(data) > window:
            total = np.cumsum(np.insert(data ** 2, 0, 0.0))
            loud = np.sqrt((total[window:] - total[:-window]).max() / window)
        else:
            loud = np.sqrt((data ** 2).mean())
        spectrum = np.abs(np.fft.rfft(data * np.hanning(len(data))))
        centre = (spectrum * np.fft.rfftfreq(len(data), 1.0 / rate)).sum() / max(spectrum.sum(), 1e-9)
        level = lambda value: 20.0 * np.log10(max(value, 1e-9))
        print("%-18s %6.2f %6.1f %6.1f %7.1f %6.0f %7.4f %7.4f" % (name[:-4], len(data) / rate, level(np.abs(data).max()),
              level(np.sqrt((data ** 2).mean())), level(loud), centre, abs(data[0]), abs(data[-1])))


def base_set():
    """The simple per-sample clips carried over from the first sound pass:
    interface click, impacts, reload, wind bed and the music loop."""
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
    render("reload", 0.8, lambda x, n, l, l2: sum(exp(-max(0, x - a) * 35) * (sin(2 * pi * f * x) * 0.3 + n * 0.2)
                                                 for a, f in [(0, 430), (0.24, 720), (0.53, 240)] if x >= a))
    render("click", 0.09, lambda x, n, l, l2: sin(2 * pi * 880 * x) * exp(-x * 55) * 0.4)
    render("impact", 0.65, lambda x, n, l, l2: n * 0.4 * exp(-x * 18) + sin(2 * pi * 110 * x) * exp(-x * 9) * 0.35)
    wind_bed()
    render("impact_flesh", 0.32, lambda x, n, l, l2: l * 0.9 * exp(-x * 30) + sin(2 * pi * (70 * x - 15 * x * x)) * 0.5 * exp(-x * 14) + n * 0.12 * exp(-x * 45))
    render("impact_metal", 0.9, lambda x, n, l, l2: sum(a * sin(2 * pi * f * x) * exp(-x * d) for f, a, d in [(1180, 0.5, 7), (1870, 0.35, 9), (2760, 0.22, 12)])
           + n * 0.35 * exp(-x * 60))
    render("critical", 0.7, lambda x, n, l, l2: sum(a * sin(2 * pi * f * x) * exp(-x * d) for f, a, d in [(1320, 0.45, 6), (1980, 0.3, 8), (2640, 0.18, 11)])
           + n * 0.08 * exp(-x * 90))
    # The title theme is built by music_theme(): oscillators only, no noise bed.


def music_theme():
    """A looping bass bed for the title: sub, a walking bass and a dark pad.
    Integer frequencies over 48 seconds so the loop meets itself. No noise,
    no hats: the old hiss was the hat, and it read as a fault on a phone."""
    seconds = 48.0
    x = t(seconds)
    # Four bars of twelve seconds. Roots are integer Hz so 48 s is a whole number of cycles.
    chords = [(55, 110, 165, 220), (44, 88, 132, 176), (49, 98, 147, 196), (41, 82, 123, 164)]
    out = np.zeros_like(x)
    bar = 12.0
    for index, chord in enumerate(chords):
        start = int(index * bar * RATE)
        end = int((index + 1) * bar * RATE)
        clock = x[start:end]
        beat = clock - index * bar
        breathe = 0.78 + 0.22 * np.sin(2.0 * np.pi * clock / 6.0)
        pad = np.zeros_like(clock)
        for freq in chord:
            pad += np.sin(2.0 * np.pi * freq * clock)
        pad *= 0.042 * breathe
        pulse = np.exp(-(beat % 0.75) * 5.2)
        bass = np.sin(2.0 * np.pi * chord[0] * clock) * 0.36 * pulse
        sub = np.sin(2.0 * np.pi * (chord[0] * 0.5) * clock) * 0.30 * (0.62 + 0.38 * pulse)
        kick = np.sin(2.0 * np.pi * 42.0 * (beat % 1.5)) * 0.40 * np.exp(-(beat % 1.5) * 8.0)
        out[start:end] = pad + bass + sub + kick
    out = np.tanh(out * 1.12)
    # Looping bed: do not fade the ends to zero (that would thump every 48 s).
    samples = np.asarray(out, np.float64)
    samples = samples - samples.mean()
    top = np.abs(samples).max()
    if top > 0:
        samples = samples / top * 0.86
    data = np.round(samples * 32767.0).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, "music_theme.wav"), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())
    print("audio %-18s %.2fs" % ("music_theme", seconds))


GROUPS = {
    "theme": music_theme,
    "hmg": lambda: (hmg_shot(), hmg_tail()),
    "rotary": rotary_gun,
    "dry_fire": dry_fire,
    "headshot": headshot,
    "mechanics": mechanics,
    "zombies": zombies,
    "giants": giants,
    "bodies": bodies,
    "defenses": defenses,
    "signals": signals,
    "explosives": explosives,
    "interface": interface,
    "endings": endings,
    "wind": wind_bed,
}


def main():
    if "--check" in sys.argv:
        check()
        return
    only = [name for argument in sys.argv if argument.startswith("--only=") for name in argument.split("=", 1)[1].split(",")]
    if only:
        for name in only:
            GROUPS[name]()
        return
    if "--base" in sys.argv:
        base_set()
    for name, build in GROUPS.items():
        # The wind bed belongs to the base set; it is only rebuilt when asked for.
        if name != "wind":
            build()


if __name__ == "__main__":
    main()
