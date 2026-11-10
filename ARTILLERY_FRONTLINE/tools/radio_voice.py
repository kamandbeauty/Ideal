#!/usr/bin/env python3
"""Turns clean TTS lines into short, urgent field-radio clips.

Usage: radio_voice.py RAW_DIR OUT_DIR
Input : mono 16-bit PCM WAV files named <id>.wav (any sample rate).
Output: mono 16-bit 24 kHz WAV files <id>.wav in OUT_DIR.

Chain: speed-up (urgency), band-pass 350-2600 Hz with a nasal mid boost (handset),
peak compression (stressed, loud but controlled), hard drive, signal dropouts,
static hiss, crackle, and squelch clicks at both ends. Deterministic: seeded noise.
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 24000
SPEED = 1.08  # faster delivery reads as urgency and stress


def read_mono(path):
    with wave.open(path, "rb") as f:
        assert f.getsampwidth() == 2, "expected 16-bit PCM"
        rate = f.getframerate()
        channels = f.getnchannels()
        raw = f.readframes(f.getnframes())
    samples = struct.unpack("<%dh" % (len(raw) // 2), raw)
    if channels == 2:
        samples = samples[0::2]
    return [s / 32768.0 for s in samples], rate


def resample(samples, rate, target, speed):
    # Linear interpolation; speed > 1 shortens the clip.
    step = (rate / target) * speed
    out = []
    position = 0.0
    last = len(samples) - 1
    while position < last:
        index = int(position)
        frac = position - index
        out.append(samples[index] * (1.0 - frac) + samples[index + 1] * frac)
        position += step
    return out


class Biquad:
    def __init__(self, kind, freq, q=0.707, gain_db=0.0):
        w0 = 2.0 * math.pi * freq / RATE
        alpha = math.sin(w0) / (2.0 * q)
        cos_w0 = math.cos(w0)
        if kind == "hp":
            b = [(1 + cos_w0) / 2, -(1 + cos_w0), (1 + cos_w0) / 2]
            a = [1 + alpha, -2 * cos_w0, 1 - alpha]
        elif kind == "lp":
            b = [(1 - cos_w0) / 2, 1 - cos_w0, (1 - cos_w0) / 2]
            a = [1 + alpha, -2 * cos_w0, 1 - alpha]
        else:  # peaking EQ
            amp = 10 ** (gain_db / 40.0)
            b = [1 + alpha * amp, -2 * cos_w0, 1 - alpha * amp]
            a = [1 + alpha / amp, -2 * cos_w0, 1 - alpha / amp]
        self.b = [x / a[0] for x in b]
        self.a = [x / a[0] for x in a[1:]]
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def run(self, samples):
        b0, b1, b2 = self.b
        a1, a2 = self.a
        out = []
        for x in samples:
            y = b0 * x + b1 * self.x1 + b2 * self.x2 - a1 * self.y1 - a2 * self.y2
            self.x2, self.x1 = self.x1, x
            self.y2, self.y1 = self.y1, y
            out.append(y)
        return out


def tone(length, freq, level, fade_out=True):
    out = []
    for i in range(length):
        t = i / RATE
        env = math.exp(-t * 22.0) if fade_out else 1.0
        out.append(math.sin(2 * math.pi * freq * t) * level * env)
    return out


def squelch_open(rng):
    burst = [rng.uniform(-1, 1) * 0.35 * math.exp(-i / (RATE * 0.02)) for i in range(int(RATE * 0.03))]
    return burst + tone(int(RATE * 0.07), 1800.0, 0.18)


def squelch_close(rng):
    burst = [rng.uniform(-1, 1) * 0.3 * math.exp(-i / (RATE * 0.012)) for i in range(int(RATE * 0.025))]
    return tone(int(RATE * 0.05), 1200.0, 0.2) + burst


def compress(samples, threshold=0.18, ratio=4.0, attack=0.002, release=0.08):
    # Feed-forward peak compressor: a shouted line stays loud but never spikes,
    # which is how a handset under stress sounds.
    a = math.exp(-1.0 / (RATE * attack))
    r = math.exp(-1.0 / (RATE * release))
    env = 0.0
    out = []
    for x in samples:
        level = abs(x)
        env = level if level > env else env * r + level * (1.0 - r)
        gain = 1.0
        if env > threshold:
            gain = (threshold + (env - threshold) / ratio) / env
        out.append(x * gain)
    return out


def crackle(length, rng):
    # Sparse clicks from a worn handset and poor signal.
    out = [0.0] * length
    for i in range(length):
        if rng.random() < 0.00006:
            amp = rng.uniform(0.15, 0.3) * (1 if rng.random() < 0.5 else -1)
            for k in range(min(72, length - i)):
                out[i + k] += amp * math.exp(-k / 14.0)
    return out


def dropouts(length, rng):
    # Signal fades between words: slow random gain steps every 0.2 s.
    gains = []
    step = int(RATE * 0.2)
    level = 1.0
    for i in range(length):
        if i % step == 0:
            level = rng.uniform(0.55, 1.0)
        gains.append(level)
    return gains


def process(samples, rate, rng):
    speech = resample(samples, rate, RATE, SPEED)
    for filt in (Biquad("hp", 350.0, 0.9), Biquad("lp", 2600.0, 0.8),
                 Biquad("lp", 2600.0, 0.8), Biquad("pk", 1800.0, 1.0, 6.0)):
        speech = filt.run(speech)
    speech = compress(speech)
    speech = [math.tanh(4.0 * x) / math.tanh(4.0) for x in speech]
    fade = dropouts(len(speech), rng)
    speech = [s * g for s, g in zip(speech, fade)]
    hiss = Biquad("hp", 1200.0, 0.707).run([rng.uniform(-1, 1) * 0.02 for _ in range(len(speech))])
    crack = crackle(len(speech), rng)
    pad = [0.0] * int(RATE * 0.06)
    body = [s + h + c for s, h, c in zip(speech, hiss, crack)]
    out = squelch_open(rng) + pad + body + pad + squelch_close(rng)
    peak = max(1e-6, max(abs(v) for v in out))
    gain = 0.8 / peak
    return [max(-1.0, min(1.0, v * gain)) for v in out]


def write_wav(path, samples):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in samples))


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    raw_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    names = sorted(n for n in os.listdir(raw_dir) if n.endswith(".wav"))
    for index, name in enumerate(names):
        samples, rate = read_mono(os.path.join(raw_dir, name))
        rng = random.Random(1000 + index)
        write_wav(os.path.join(out_dir, name), process(samples, rate, rng))
        print("radio:", name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
