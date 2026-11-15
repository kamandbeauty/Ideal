#!/usr/bin/env python3
"""Synthesise the whole soundtrack and every sound effect of the game.

The game ships no recorded audio: everything under ``assets/audio/`` is built by
this script so the soundtrack is reproducible, licence-free and tiny.

    python3 tools/build_audio.py

Output (OGG Vorbis, mono, 44.1 kHz):

    assets/audio/music/menu.ogg   tooltip-smooth 1950s diner loop for the title
    assets/audio/music/day.ogg    bright walking-bass loop for daytime play
    assets/audio/music/night.ogg  mellow minor loop for the night shift
    assets/audio/sfx/*.ogg        fourteen one-shots (coin, cash, build, ...)

The instruments are deliberately simple additive/FM voices with a short
convolution reverb, which is exactly the palette a 1950s roadside stop wants:
electric piano, upright bass, brushed snare, tambourine, vibraphone lead.
"""

from __future__ import annotations

import math
import os
import wave

import numpy as np
import soundfile as sf

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
RNG = np.random.default_rng(1957)


# --- Primitives -------------------------------------------------------------

def midi(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR), dtype=np.float64) / SR


def env(seconds: float, attack: float, decay: float, sustain: float = 0.0,
        release: float = 0.0, sustain_level: float = 0.6) -> np.ndarray:
    """Linear ADSR envelope; release is measured from the end of the note."""
    n = int(seconds * SR)
    out = np.zeros(n)
    a = min(int(attack * SR), n)
    d = min(int(decay * SR), max(0, n - a))
    r = min(int(release * SR), max(0, n - a - d))
    s = max(0, n - a - d - r)
    if a:
        out[:a] = np.linspace(0.0, 1.0, a)
    if d:
        out[a:a + d] = np.linspace(1.0, sustain_level, d)
    if s:
        out[a + d:a + d + s] = sustain_level
    if r:
        out[a + d + s:] = np.linspace(sustain_level, 0.0, r)
    return out


def lowpass(sig: np.ndarray, cutoff: float) -> np.ndarray:
    """One-pole low pass; enough to take the fizz off noise and saws."""
    alpha = math.exp(-2.0 * math.pi * cutoff / SR)
    out = np.empty_like(sig)
    acc = 0.0
    for i, value in enumerate(sig):
        acc = (1.0 - alpha) * value + alpha * acc
        out[i] = acc
    return out


def highpass(sig: np.ndarray, cutoff: float) -> np.ndarray:
    return sig - lowpass(sig, cutoff)


def reverb(sig: np.ndarray, seconds: float = 0.55, mix: float = 0.15,
           seed: int = 7) -> np.ndarray:
    """Convolution with a decaying noise tail: a small, believable room."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 4.5))
    ir[: int(0.012 * SR)] = 0.0          # predelay so the attack stays dry
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    size = 1 << int(math.ceil(math.log2(len(sig) + n)))
    wet = np.fft.irfft(np.fft.rfft(sig, size) * np.fft.rfft(ir, size), size)[: len(sig)]
    return (1.0 - mix) * sig + mix * wet * 3.0


# --- Voices -----------------------------------------------------------------

def electric_piano(freq: float, seconds: float, vel: float = 1.0) -> np.ndarray:
    t = t_axis(seconds)
    vibrato = 1.0 + 0.0018 * np.sin(2 * math.pi * 5.2 * t)
    phase = 2 * math.pi * freq * vibrato * t
    body = np.sin(phase) + 0.34 * np.sin(2 * phase) + 0.12 * np.sin(3 * phase)
    tine = np.sin(2 * math.pi * freq * 4.02 * t) * np.exp(-t * 18.0) * 0.18
    tone = (body * np.exp(-t * 2.6) + tine) * vel
    return tone * env(seconds, 0.006, seconds * 0.9, release=0.05, sustain_level=0.25)


def upright_bass(freq: float, seconds: float, vel: float = 1.0) -> np.ndarray:
    t = t_axis(seconds)
    phase = 2 * math.pi * freq * t
    tone = np.sin(phase) + 0.42 * np.sin(2 * phase) + 0.18 * np.sin(3 * phase)
    thump = np.sin(2 * math.pi * freq * 0.5 * t) * np.exp(-t * 22.0) * 0.35
    return (tone + thump) * np.exp(-t * 3.4) * vel


def vibraphone(freq: float, seconds: float, vel: float = 1.0) -> np.ndarray:
    t = t_axis(seconds)
    trem = 0.78 + 0.22 * np.sin(2 * math.pi * 4.6 * t)
    phase = 2 * math.pi * freq * t
    tone = np.sin(phase) + 0.22 * np.sin(2.0 * phase) + 0.06 * np.sin(4.02 * phase)
    return tone * trem * np.exp(-t * 2.2) * vel * env(
        seconds, 0.004, seconds * 0.9, release=0.06, sustain_level=0.2)


def pad(freq: float, seconds: float, vel: float = 1.0) -> np.ndarray:
    t = t_axis(seconds)
    tone = np.zeros_like(t)
    for detune in (-0.004, 0.0, 0.004):
        tone += np.sin(2 * math.pi * freq * (1 + detune) * t)
    tone *= 0.33
    return tone * env(seconds, 0.18, 0.25, sustain=seconds - 0.5,
                      release=0.25, sustain_level=0.7) * vel


def brush(seconds: float = 0.16, vel: float = 1.0) -> np.ndarray:
    t = t_axis(seconds)
    noise = highpass(RNG.standard_normal(len(t)), 1800.0)
    return noise * np.exp(-t * 32.0) * vel


def shaker(seconds: float = 0.07, vel: float = 1.0) -> np.ndarray:
    t = t_axis(seconds)
    noise = highpass(RNG.standard_normal(len(t)), 5200.0)
    return noise * np.exp(-t * 70.0) * vel


def tambourine(seconds: float = 0.2, vel: float = 1.0) -> np.ndarray:
    t = t_axis(seconds)
    noise = highpass(RNG.standard_normal(len(t)), 4000.0)
    jingle = 0.4 * np.sin(2 * math.pi * 3100 * t)
    return (noise + jingle) * np.exp(-t * 22.0) * vel


# --- Sequencing -------------------------------------------------------------

class Song:
    """A beat grid with a wrap-around tail, so a loop joins without a seam."""

    def __init__(self, bpm: float, bars: int, beats: int = 4, swing: float = 0.0):
        self.bpm = float(bpm)
        self.bars = bars
        self.beats = beats
        self.swing = swing
        self.beat = 60.0 / bpm
        self.length = bars * beats * self.beat
        tail = 2.4
        self.buffer = np.zeros(int((self.length + tail) * SR) + 8)
        self.sr = SR

    def at(self, bar: float, beat: float = 0.0) -> int:
        """Sample index of a musical position; odd 8ths are swung."""
        if self.swing and abs(beat % 1.0 - 0.5) < 1e-6:
            beat += self.swing * 0.5
        return int((bar * self.beats + beat) * self.beat * SR)

    def add(self, signal: np.ndarray, start: int, gain: float = 1.0) -> None:
        if start >= len(self.buffer):
            return
        end = min(len(self.buffer), start + len(signal))
        self.buffer[start:end] += signal[: end - start] * gain

    def note(self, voice, note: float, bar: float, beat: float,
             dur_beats: float, gain: float = 1.0) -> None:
        seconds = max(0.08, dur_beats * self.beat * 1.15)
        self.add(voice(midi(note), seconds), self.at(bar, beat), gain)

    def build(self, gain: float = 1.0) -> np.ndarray:
        """Fold the tail back over the start and normalise."""
        n = int(self.length * SR)
        loop = self.buffer[:n].copy()
        tail = self.buffer[n:]
        loop[: len(tail)] += tail[: len(loop)]
        return loop * gain


CHORDS = {
    "C": (60, 64, 67), "Am": (57, 60, 64), "F": (53, 57, 60), "G": (55, 59, 62),
    "Dm": (50, 53, 57), "Bb": (46, 50, 53), "Em": (52, 55, 59), "A": (57, 61, 64),
}

BASS = {
    "C": 36, "Am": 45, "F": 41, "G": 43, "Dm": 38, "Bb": 34, "Em": 40, "A": 45,
}


def make_track(progression, bpm, mel, *, swing=0.12, bright=1.0, night=False):
    """One 4-beat-per-bar loop: bass, chord stabs, brush, shaker and a lead."""
    bars = len(progression)
    song = Song(bpm, bars, swing=swing)
    for bar, name in enumerate(progression):
        chord = CHORDS[name]
        root = BASS[name]
        # Walking bass: root, fifth, sixth, approach.
        walk = [root, root + 7, root + 9, root + (5 if bar % 2 else 10)]
        for beat, pitch in enumerate(walk):
            song.note(upright_bass, pitch, bar, beat, 0.95, 0.5)
        # Electric-piano stabs on 2 and 4, thin on odd bars for space.
        if not night or bar % 2 == 0:
            for i, pitch in enumerate(chord):
                song.note(electric_piano, pitch, bar, 1.0, 0.5, 0.2)
                song.note(electric_piano, pitch, bar, 3.0, 0.4, 0.16)
        if night:
            for pitch in chord:
                song.note(pad, pitch - 12, bar, 0.0, 3.9, 0.09)
        # Brushed snare and tambourine carry the backbeat.
        song.add(brush(0.16, 1.0), song.at(bar, 1.0), 0.16 * bright)
        song.add(brush(0.16, 0.85), song.at(bar, 3.0), 0.13 * bright)
        song.add(tambourine(0.18, 0.5), song.at(bar, 3.0), 0.05 * bright)
        for e in range(8):
            song.add(shaker(0.06, 0.6 if e % 2 else 0.35),
                     song.at(bar, e * 0.5), 0.035 * bright)
    for entry in mel:
        bar, beat, pitch, dur, gain = entry
        song.note(vibraphone, pitch, bar, beat, dur, gain)
    return song.build(1.0)


def music_day() -> np.ndarray:
    melody = [
        (0, 0.0, 72, 0.9, 0.30), (0, 1.5, 74, 0.4, 0.22), (0, 2.0, 76, 1.0, 0.30),
        (1, 0.0, 79, 1.6, 0.30), (1, 2.0, 76, 0.8, 0.22), (1, 3.0, 72, 0.9, 0.20),
        (2, 0.0, 69, 1.0, 0.28), (2, 1.5, 72, 0.4, 0.20), (2, 2.0, 74, 1.0, 0.28),
        (3, 0.0, 76, 1.8, 0.28), (3, 2.5, 74, 1.2, 0.22),
        (4, 0.0, 67, 1.0, 0.26), (4, 1.5, 69, 0.4, 0.20), (4, 2.0, 72, 1.0, 0.26),
        (5, 0.0, 74, 1.6, 0.26), (5, 2.5, 72, 1.0, 0.20),
        (6, 0.0, 71, 1.0, 0.26), (6, 2.0, 74, 1.0, 0.26), (6, 3.0, 79, 1.0, 0.24),
        (7, 0.0, 76, 2.0, 0.26),
    ]
    return make_track(["C", "Am", "F", "G", "C", "Am", "F", "G"], 96, melody)


def music_night() -> np.ndarray:
    melody = [
        (0, 0.0, 69, 1.6, 0.20), (0, 2.5, 72, 1.4, 0.16),
        (1, 0.0, 76, 2.0, 0.18), (1, 2.5, 72, 1.2, 0.14),
        (2, 0.0, 77, 1.6, 0.18), (2, 2.5, 76, 1.4, 0.14),
        (3, 0.0, 74, 2.4, 0.18),
        (4, 0.0, 69, 1.6, 0.20), (4, 2.5, 71, 1.4, 0.15),
        (5, 0.0, 72, 1.8, 0.18), (5, 2.5, 69, 1.4, 0.15),
        (6, 0.0, 76, 1.4, 0.17), (6, 2.0, 74, 1.4, 0.15),
        (7, 0.0, 72, 2.8, 0.18),
    ]
    return make_track(["Am", "Am", "F", "F", "C", "C", "Em", "A"], 84, melody,
                      swing=0.16, bright=0.55, night=True)


def music_menu() -> np.ndarray:
    song = Song(80, 8, swing=0.14)
    prog = ["F", "Dm", "Bb", "C", "F", "Dm", "Bb", "C"]
    for bar, name in enumerate(prog):
        chord = CHORDS[name]
        for i, pitch in enumerate(chord):
            for beat in (0.0, 2.0):
                song.note(electric_piano, pitch, bar, beat + i * 0.5, 1.4, 0.16)
        song.note(upright_bass, BASS[name], bar, 0.0, 1.9, 0.32)
        song.note(upright_bass, BASS[name] + 7, bar, 2.0, 1.9, 0.26)
        song.add(brush(0.16, 0.6), song.at(bar, 2.0), 0.07)
        for e in range(4):
            song.add(shaker(0.06, 0.3), song.at(bar, e * 0.5), 0.02)
    lead = [(0, 0.0, 72, 2.0, 0.18), (1, 0.0, 69, 2.0, 0.16),
            (2, 0.0, 70, 2.0, 0.16), (3, 0.0, 72, 3.0, 0.18),
            (4, 0.0, 77, 2.0, 0.16), (5, 0.0, 76, 2.0, 0.15),
            (6, 0.0, 74, 2.0, 0.15), (7, 0.0, 72, 3.0, 0.17)]
    for entry in lead:
        song.note(vibraphone, entry[2], entry[0], entry[1], entry[3], entry[4])
    return song.build(1.0)


# --- Sound effects ----------------------------------------------------------

def bell(freq: float, seconds: float, decay: float = 6.0, partials=(1.0, 2.01, 3.03)):
    t = t_axis(seconds)
    tone = np.zeros_like(t)
    for i, ratio in enumerate(partials):
        tone += np.sin(2 * math.pi * freq * ratio * t) / (i + 1) ** 1.4
    return tone * np.exp(-t * decay)


def noise_burst(seconds: float, cutoff: float, decay: float, gain: float = 1.0):
    t = t_axis(seconds)
    noise = highpass(RNG.standard_normal(len(t)), cutoff)
    return noise * np.exp(-t * decay) * gain


def thump(freq: float, seconds: float, decay: float = 18.0):
    t = t_axis(seconds)
    return np.sin(2 * math.pi * freq * t * np.exp(-t * 2.0)) * np.exp(-t * decay)


def silence(seconds: float) -> np.ndarray:
    return np.zeros(int(seconds * SR))


def concat(*parts) -> np.ndarray:
    return np.concatenate([p if isinstance(p, np.ndarray) else silence(p) for p in parts])


def sfx_coin():
    return reverb(concat(bell(1318.5, 0.22, 9.0), silence(0.02),
                         bell(1975.5, 0.18, 12.0) * 0.5), 0.18, 0.18)


def sfx_cash():
    drawer = concat(thump(180, 0.12, 26.0) * 0.7,
                    noise_burst(0.1, 900, 40.0, 0.5))
    return concat(bell(1568.0, 0.3, 7.0) * 0.8, silence(0.05), drawer)


def sfx_build():
    hit = concat(thump(120, 0.16, 22.0), noise_burst(0.09, 1400, 45.0, 0.55))
    return reverb(concat(hit, silence(0.06), hit * 0.7), 0.22, 0.12)


def sfx_upgrade():
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for i, freq in enumerate(notes):
        parts.append(bell(freq, 0.28, 8.0) * (0.5 + 0.12 * i))
    return reverb(concat(*[concat(p, 0.0) for p in parts]), 0.3, 0.2)


def sfx_levelup():
    parts = [bell(f, 0.34, 7.0) * 0.6 for f in (392.0, 523.25, 659.25, 784.0)]
    shimmer = noise_burst(0.5, 6000, 9.0, 0.12)
    return reverb(concat(*parts, shimmer), 0.4, 0.25)


def sfx_mission():
    return reverb(concat(bell(783.99, 0.3, 8.0), bell(1046.5, 0.6, 6.0)), 0.35, 0.2)


def sfx_gem():
    t = t_axis(0.5)
    sparkle = np.zeros_like(t)
    for i, freq in enumerate((2093.0, 2637.0, 3136.0, 3520.0)):
        start = int(i * 0.045 * SR)
        tone = bell(freq, 0.5 - i * 0.045, 9.0, (1.0, 2.4))[: len(t) - start]
        sparkle[start:start + len(tone)] += tone * (0.5 - 0.08 * i)
    return reverb(sparkle, 0.4, 0.3)


def sfx_hire():
    t = t_axis(0.55)
    glide = np.sin(2 * math.pi * np.cumsum(300 + 900 * (t / 0.55) ** 1.5) / SR)
    whistle = glide * np.exp(-t * 4.0) * 0.45
    return reverb(concat(whistle, bell(880.0, 0.3, 9.0) * 0.4), 0.3, 0.22)


def sfx_event():
    a = concat(bell(880.0, 0.14, 12.0), bell(880.0, 0.1, 14.0))
    b = concat(bell(659.25, 0.14, 12.0), bell(523.25, 0.3, 9.0))
    return reverb(concat(a, b), 0.3, 0.2)


def sfx_click():
    return noise_burst(0.05, 2600, 90.0, 0.5) + thump(760, 0.05, 90.0) * 0.2


def sfx_deny():
    t = t_axis(0.22)
    buzz = np.sign(np.sin(2 * math.pi * 132 * t)) * 0.22
    return lowpass(buzz, 1600) * env(0.22, 0.005, 0.05, sustain=0.14, release=0.03)


def sfx_complete():
    triads = [(392.0, 493.88, 587.33), (523.25, 659.25, 783.99),
              (659.25, 783.99, 987.77), (783.99, 987.77, 1174.66)]
    parts = []
    for i, chord in enumerate(triads):
        block = sum(bell(f, 0.42, 6.0) for f in chord) / 3.0
        parts.append(block * (0.55 + 0.1 * i))
    return reverb(concat(*parts, bell(1567.98, 0.9, 4.0) * 0.5), 0.5, 0.3)


def sfx_whoosh():
    t = t_axis(0.6)
    noise = RNG.standard_normal(len(t))
    sweep = lowpass(noise, 900) * np.linspace(0.0, 1.0, len(t)) ** 2
    sweep *= np.exp(-((t - 0.28) ** 2) / 0.02)
    return sweep * 0.5


def sfx_pop():
    return bell(1046.5, 0.12, 26.0, (1.0, 2.0)) * 0.5


def sfx_travel():
    t = t_axis(1.0)
    engine = np.sin(2 * math.pi * np.cumsum(70 + 60 * t) / SR) * 0.25
    engine *= np.hanning(len(t))
    return reverb(concat(engine, noise_burst(0.6, 700, 5.0, 0.1)), 0.4, 0.2)


def sfx_ambience(seconds: float = 12.0):
    """Desert wind plus a far-off pick-up: cheap but keeps night alive."""
    t = t_axis(seconds)
    wind = lowpass(RNG.standard_normal(len(t)), 420)
    wind *= 0.35 + 0.25 * np.sin(2 * math.pi * 0.07 * t)
    crickets = np.zeros_like(t)
    for i in range(9):
        start = int((0.4 + i * 1.31) * SR)
        chirp = bell(4200 + (i % 3) * 130, 0.09, 40.0, (1.0,)) * 0.05
        end = min(len(t), start + len(chirp))
        crickets[start:end] += chirp[: end - start]
    return reverb(wind * 0.5 + crickets, 0.6, 0.2)


# --- Writing ----------------------------------------------------------------

def to_loop(path: str, data: np.ndarray, peak: float = 0.85) -> None:
    data = data - float(np.mean(data))
    scale = peak / (np.max(np.abs(data)) + 1e-9)
    scaled = np.tanh(data * scale * 1.15) / math.tanh(1.15)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, scaled.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print(f"  {os.path.relpath(path, ROOT):40s} {len(scaled) / SR:6.2f}s")


def main() -> None:
    print("music")
    to_loop(os.path.join(AUDIO, "music", "day.ogg"), music_day(), 0.8)
    to_loop(os.path.join(AUDIO, "music", "night.ogg"), music_night(), 0.78)
    to_loop(os.path.join(AUDIO, "music", "menu.ogg"), music_menu(), 0.8)

    print("sound effects")
    effects = {
        "coin": sfx_coin, "cash": sfx_cash, "build": sfx_build,
        "upgrade": sfx_upgrade, "levelup": sfx_levelup, "mission": sfx_mission,
        "gem": sfx_gem, "hire": sfx_hire, "event": sfx_event,
        "click": sfx_click, "deny": sfx_deny, "complete": sfx_complete,
        "whoosh": sfx_whoosh, "pop": sfx_pop, "travel": sfx_travel,
    }
    for name, builder in effects.items():
        to_loop(os.path.join(AUDIO, "sfx", f"{name}.ogg"), builder(), 0.9)

    wind = sfx_ambience()
    to_loop(os.path.join(AUDIO, "ambience.ogg"), wind, 0.5)


def write_wav_variant(path: str, data: np.ndarray) -> None:
    """Unused fallback kept for machines without libsndfile's OGG support."""
    pcm = np.clip(data, -1.0, 1.0)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes((pcm * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    main()
