#!/usr/bin/env python3
"""Generate the port's sound set from scratch.

The Unity project ships no audio at all, so there is nothing to migrate — but a match-3 without sound
is not finished. Every file here is synthesised by this script from sine partials and shaped noise:
no samples, no libraries, nothing owned by anybody else. Running it again reproduces the same bytes,
which is the point: the assets are build output, not mystery binaries.

    python3 godot-port/tools/make_audio.py

Writes 44.1 kHz mono 16-bit PCM WAV into godot-port/assets/audio/.
"""

from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "audio"
rng = np.random.default_rng(20261107)

# D "shur"-flavoured scale used by the music and the match chimes: it sounds like the palace the art
# draws, and it keeps every cue consonant with every other cue.
D5 = 587.33
SCALE = {
    "d4": 293.66,
    "eb4": 311.13,
    "f4": 349.23,
    "g4": 392.00,
    "a4": 440.00,
    "bb4": 466.16,
    "c5": 523.25,
    "d5": D5,
    "eb5": 622.25,
    "f5": 698.46,
    "g5": 783.99,
    "a5": 880.00,
    "bb5": 932.33,
    "c6": 1046.50,
    "d6": 1174.66,
    "f6": 1396.91,
    "a6": 1760.00,
}


def t_axis(seconds: float) -> np.ndarray:
    return np.linspace(0.0, seconds, int(RATE * seconds), endpoint=False)


def envelope(count: int, attack: float, decay: float, curve: float = 3.0) -> np.ndarray:
    """A fast attack and an exponential decay, the shape of a struck string."""
    attack_samples = max(1, int(RATE * attack))
    env = np.ones(count)
    env[:attack_samples] = np.linspace(0.0, 1.0, attack_samples)
    tail = np.linspace(0.0, 1.0, count - attack_samples)
    env[attack_samples:] = np.exp(-curve * tail * (1.0 / max(decay, 1e-6)))
    return env


def pluck(frequency: float, seconds: float, brightness: float = 0.35, decay: float = 0.45) -> np.ndarray:
    """Additive pluck: fundamental plus a few harmonics that die faster than the root."""
    time = t_axis(seconds)
    signal = np.zeros_like(time)
    for harmonic in range(1, 7):
        amplitude = brightness ** (harmonic - 1)
        signal += amplitude * np.sin(2.0 * math.pi * frequency * harmonic * time)
    signal /= np.max(np.abs(signal)) + 1e-9
    return signal * envelope(signal.size, 0.004, decay)


def click(seconds: float = 0.012, level: float = 0.25) -> np.ndarray:
    noise = rng.normal(0.0, 1.0, int(RATE * seconds))
    return noise * np.linspace(level, 0.0, noise.size)


def sweep(f_start: float, f_end: float, seconds: float) -> np.ndarray:
    time = t_axis(seconds)
    phase = 2.0 * math.pi * np.cumsum(np.linspace(f_start, f_end, time.size)) / RATE
    signal = np.sin(phase) * envelope(time.size, 0.01, 0.5, curve=2.0)
    return signal / (np.max(np.abs(signal)) + 1e-9)


def noise(seconds: float) -> np.ndarray:
    return rng.normal(0.0, 1.0, int(RATE * seconds))


def lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    """A one-pole low pass: the cheapest way to turn white noise into water rather than hiss."""
    alpha = min(1.0, 2.0 * math.pi * cutoff / RATE)
    out = np.zeros_like(signal)
    state = 0.0
    for index in range(signal.size):
        state += alpha * (signal[index] - state)
        out[index] = state
    return out


def band(signal: np.ndarray, low: float, high: float) -> np.ndarray:
    return lowpass(signal, high) - lowpass(signal, low)


def swell(signal: np.ndarray, peak_at: float = 0.35, curve: float = 1.6) -> np.ndarray:
    """An amplitude shape that opens and closes: the outline of a gust, not of a drum."""
    count = signal.size
    position = np.linspace(0.0, 1.0, count)
    rise = np.clip(position / max(peak_at, 1e-6), 0.0, 1.0) ** curve
    fall = np.clip((1.0 - position) / max(1.0 - peak_at, 1e-6), 0.0, 1.0) ** (curve * 0.8)
    return signal * np.minimum(rise, fall)


def mix(*parts: np.ndarray) -> np.ndarray:
    length = max(part.size for part in parts)
    out = np.zeros(length)
    for part in parts:
        out[: part.size] += part
    peak = np.max(np.abs(out))
    return out / peak if peak > 0 else out


def pad(signal: np.ndarray, head: float = 0.0, tail: float = 0.02) -> np.ndarray:
    pieces = []
    if head > 0:
        pieces.append(np.zeros(int(RATE * head)))
    pieces.append(signal)
    pieces.append(np.zeros(int(RATE * tail)))
    return np.concatenate(pieces)


def write(name: str, signal: np.ndarray, gain: float = 0.8) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    peak = np.max(np.abs(signal)) or 1.0
    pcm = np.clip(signal / peak * gain, -1.0, 1.0)
    data = (pcm * 32767.0).astype("<i2")
    path = OUT_DIR / name
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())
    print(f"{path.name}: {signal.size / RATE:.2f}s, {path.stat().st_size // 1024} KiB")


def music_loop() -> np.ndarray:
    """Eight bars of slow santur-ish arpeggio on a D drone, folded into a seamless loop."""
    bpm = 72.0
    beat = 60.0 / bpm
    bars = 8
    loop_seconds = bars * 4 * beat
    total = int(RATE * (loop_seconds + 3.0))
    buffer = np.zeros(total)

    pattern = ["d4", "a4", "f4", "c5", "d5", "a4", "g4", "f4"]
    step = beat / 2.0
    position = 0.0
    index = 0
    while position < loop_seconds:
        note = SCALE[pattern[index % len(pattern)]]
        voice = pluck(note, 1.8, brightness=0.28, decay=0.9) * 0.5
        start = int(RATE * position)
        end = min(total, start + voice.size)
        buffer[start:end] += voice[: end - start]
        position += step
        index += 1

    # drone
    time = np.linspace(0.0, total / RATE, total, endpoint=False)
    drone = 0.12 * np.sin(2.0 * math.pi * SCALE["d4"] / 2.0 * time)
    drone += 0.06 * np.sin(2.0 * math.pi * SCALE["a4"] / 2.0 * time)
    buffer += drone

    # Fold everything that ran past the loop point back onto the start: the seam disappears because
    # the tail of the last note is played at the head of the loop instead of being cut off.
    loop_samples = int(RATE * loop_seconds)
    looped = buffer[:loop_samples].copy()
    looped[: total - loop_samples] += buffer[loop_samples:]
    fade = int(RATE * 0.008)
    looped[:fade] *= np.linspace(0.0, 1.0, fade)
    looped[-fade:] *= np.linspace(1.0, 0.0, fade)
    return looped


def main() -> int:
    write("ui_tap.wav", pad(mix(pluck(SCALE["a5"], 0.09, 0.2, 0.2), click(0.01, 0.12)), tail=0.01), 0.5)
    write("swap.wav", pad(mix(sweep(420.0, 760.0, 0.16) * 0.8, click(0.02, 0.10))), 0.45)
    write("match.wav", pad(pluck(SCALE["d5"], 0.38, 0.35, 0.5)), 0.7)
    write("cascade.wav", pad(pluck(SCALE["a5"], 0.40, 0.40, 0.55)), 0.65)
    write("power_up.wav", pad(mix(pluck(SCALE["f5"], 0.5, 0.5, 0.6), sweep(600.0, 1500.0, 0.35) * 0.5)), 0.7)
    write("reject.wav", pad(mix(pluck(SCALE["d4"] / 2.0, 0.16, 0.15, 0.25), click(0.03, 0.2))), 0.6)
    write("reward.wav", pad(mix(pluck(SCALE["a5"], 0.3, 0.3, 0.4), pluck(SCALE["d6"], 0.5, 0.3, 0.5) * 0.8)), 0.7)

    # The event cues. A clear is a soft third so it can fire repeatedly inside one cascade without
    # becoming a melody of its own; an obstacle hit is a wooden knock well below the chimes; a combo is
    # the only rising figure in the set, so a chain is audible before the bonus is read; making a
    # power-up shimmers upward, the mirror of using one.
    clear = np.concatenate([pluck(SCALE["a5"], 0.14, 0.3, 0.3), pluck(SCALE["c6"], 0.2, 0.3, 0.35) * 0.7])
    write("clear.wav", pad(clear, tail=0.02), 0.6)
    write("obstacle.wav", pad(mix(pluck(SCALE["d4"] / 2.0, 0.2, 0.2, 0.22), click(0.02, 0.22)), tail=0.02), 0.65)
    combo = np.concatenate([pluck(SCALE[name], 0.16, 0.4, 0.35) for name in ("a5", "c6", "f6")])
    write("combo.wav", pad(combo, tail=0.04), 0.7)
    make_power = mix(sweep(700.0, 1800.0, 0.34) * 0.8, pluck(SCALE["f6"], 0.36, 0.35, 0.4) * 0.5)
    write("powerup_create.wav", pad(make_power, tail=0.03), 0.6)

    # ---- the juice and the special pieces ------------------------------------------------------
    # A fruit bursting is wet, not bright: a short low-noise splash with a plop under it. The chime
    # above it stays, but it is the fruit's colour rather than its body.
    splash = lowpass(noise(0.26), 2600.0) * np.linspace(1.0, 0.0, int(RATE * 0.26)) ** 2.0
    plop = sweep(420.0, 120.0, 0.20) * 0.55
    write("burst.wav", pad(mix(splash * 0.9, plop, pluck(SCALE["c6"], 0.16, 0.25, 0.25) * 0.25),
                          tail=0.03), 0.62)

    # The fan: a gust that opens and closes, with the whistle of air over the blades on top of it.
    gust = band(noise(0.62), 320.0, 2100.0)
    tremolo = 1.0 + 0.35 * np.sin(2.0 * math.pi * 7.5 * t_axis(0.62))
    gust = swell(gust * tremolo, 0.30, 1.4)
    blade = np.sin(2.0 * math.pi * np.cumsum(np.linspace(520.0, 980.0, int(RATE * 0.62))) / RATE)
    write("whirlwind.wav", pad(mix(gust, blade * swell(np.ones(int(RATE * 0.62)), 0.35) * 0.18),
                              tail=0.03), 0.55)

    # The rocket: air rushing past for half a second, then the crack of the row going.
    rush = band(noise(0.42), 600.0, 5200.0)
    rush = swell(rush, 0.72, 2.2)
    crack = lowpass(noise(0.16), 900.0) * np.linspace(1.0, 0.0, int(RATE * 0.16)) ** 1.4
    write("rocket.wav", pad(mix(rush, crack * 0.9, pluck(SCALE["d4"] / 2.0, 0.24, 0.2, 0.3) * 0.4),
                            tail=0.04), 0.62)

    # The kite: a light rising whistle with a flutter, and nothing underneath it.
    flight = sweep(700.0, 1500.0, 0.34)
    flutter = 1.0 + 0.25 * np.sin(2.0 * math.pi * 11.0 * t_axis(0.34))
    write("kite.wav", pad(flight * flutter * 0.8, tail=0.03), 0.5)

    win = np.concatenate([pluck(SCALE[name], 0.9, 0.35, 0.7) for name in ("d5", "f5", "a5", "d6")])
    write("win.wav", pad(win, tail=0.05), 0.75)
    lose = np.concatenate([pluck(SCALE[name], 0.8, 0.25, 0.6) for name in ("d5", "a4", "f4")])
    write("lose.wav", pad(lose, tail=0.05), 0.65)

    write("music_palace.wav", music_loop(), 0.55)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
