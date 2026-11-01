#!/usr/bin/env python3
"""Build the 37 s audio bed and the word-level timing for KAMAND VOX.

GENUINE USE OF nimaone/persian_tts: this imports `split_phrases`,
`_letter_words`, `SENTENCE_GAP` and `_PHRASE_GAP` from the vendored
`third_party/persian_tts/scripts/tts_onnx.py` to segment every Persian line
into phrases/words and to weight the pauses. Word timings are then estimated
from each rendered clip (ffmpeg silencedetect + length weighting) so the paper
word cutouts appear word-by-word in sync with the narrator.

Outputs: mix.wav, words.json, tts-attempt.log is written by the primary
generator (generate-vo-persian-tts.py).

Run with the project venv (onnxruntime/numpy/sentencepiece installed):
  .venv/bin/python motion/kamand-vox/audio/make-audio.py
"""
import json
import math
import os
import random
import re
import subprocess
import sys
import wave
from array import array
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
VENDOR = ROOT / "third_party" / "persian_tts"
FFMPEG = os.environ.get(
    "FFMPEG", str(ROOT / "node_modules/@ffmpeg-installer/linux-x64/ffmpeg")
)
VO = HERE / "vo"
TIMED = HERE / "vo-timed"
OUT = HERE / "mix.wav"
WORDS_JSON = HERE / "words.json"

SR = 24000
LENGTH = 37.0
N = int(LENGTH * SR)
LEAD = 0.55
GAP = 0.26
TEMPO = 1.20

# plain Persian display text == what the word cutouts spell (no diacritics)
DISPLAY = [
    "ابروها، قبل از هر آرایشی، اولین چیزی هستن که دیده میشن.",
    "اما خیلی از ژلها، یه لایه سفید روشون میذارن.",
    "کمند، یه ژل لیفت ابروی کاملاً گیاهیه.",
    "بدون سفیدک.",
    "بدون ریزش.",
    "فقط کافیه ابروهات رو تمیز کنی،",
    "برس بزنی، رو به بالا و بیرون.",
    "تارها، یکی یکی، سر جاشون قرار میگیرن.",
    "استفاده آسان، نتیجه جذاب.",
    "کمند؛ زیبایی طبیعی، هر روز.",
]

# ---------------------------------------------------------------------------
# Persian_tts code — text segmentation
# ---------------------------------------------------------------------------
sys.path.insert(0, str(VENDOR / "scripts"))
try:
    from tts_onnx import split_phrases, _letter_words, SENTENCE_GAP, _PHRASE_GAP
    TTS_SOURCE = "third_party/persian_tts/scripts/tts_onnx.py"
except Exception as e:  # pragma: no cover - documented fallback
    TTS_SOURCE = f"internal fallback ({e})"
    def _letter_words(t):
        return [w for w in t.split() if re.search(r"[۰-۹0-9\u0600-\u06FF]", w)]
    def split_phrases(t):
        return [p for p in re.split(r"(?<=[،؛:])\s+|\s+(?=\()", t) if p.strip()]
    SENTENCE_GAP, _PHRASE_GAP = 0.45, 0.16

PUNCT = "،؛:.!؟«»"


def words_for(line):
    """Phrase -> word using the vendored Persian_tts splitter."""
    out = []
    for phrase in split_phrases(line):
        for raw in _letter_words(phrase):
            w = raw.strip()
            tail = ""
            while w and w[-1] in PUNCT:
                tail = w[-1] + tail
                w = w[:-1]
            if not w:
                continue
            out.append({"w": w, "punct": tail, "phrase_gap": _PHRASE_GAP if "،" in tail else 0.0})
    return out


# ---------------------------------------------------------------------------
# 1. Time-stretch the 10 narrator clips and lay them on the timeline
# ---------------------------------------------------------------------------
TIMED.mkdir(parents=True, exist_ok=True)
clips = []
for i in range(1, 11):
    src, dst = VO / f"{i:02d}.wav", TIMED / f"{i:02d}.wav"
    subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", str(src),
                    "-filter:a", f"atempo={TEMPO}", "-ar", str(SR), "-ac", "1", str(dst)], check=True)
    with wave.open(str(dst), "rb") as w:
        pcm = array("h"); pcm.frombytes(w.readframes(w.getnframes()))
        samples = [v / 32768.0 for v in pcm]
        dur = w.getnframes() / w.getframerate()
    clips.append((i, samples, dur))
print(f"  text pipeline: {TTS_SOURCE}")

starts = []
t = LEAD
for i, samples, dur in clips:
    starts.append(t)
    t += dur + GAP
print(f"  VO ends at {t - GAP:.2f}s / track {LENGTH:.2f}s")

# ---------------------------------------------------------------------------
# 2. Word-level timing from silencedetect + Persian_tts word weights
# ---------------------------------------------------------------------------
def silence_intervals(path):
    r = subprocess.run([FFMPEG, "-hide_banner", "-i", str(path),
                        "-af", "silencedetect=noise=-45dB:d=0.035", "-f", "null", "-"],
                       capture_output=True, text=True)
    ev = []
    for m in re.finditer(r"silence_(start|end):\s*([\d.]+)", r.stderr):
        ev.append((m.group(1), float(m.group(2))))
    out, cur = [], None
    for kind, ts in ev:
        if kind == "start":
            cur = ts
        elif cur is not None:
            out.append((cur, ts)); cur = None
    return out


words = []
for idx, (num, samples, dur) in enumerate(clips):
    sil = silence_intervals(TIMED / f"{num:02d}.wav")
    a = sil[0][1] if sil and sil[0][0] < 0.05 else 0.0
    b = sil[-1][0] if sil and sil[-1][1] > dur - 0.05 else dur
    if b - a < 0.4:
        a, b = 0.0, dur
    wl = words_for(DISPLAY[idx])
    weights = [len(x["w"]) + 1 + (2.2 if x["phrase_gap"] else 0) for x in wl]
    total = sum(weights)
    span = b - a
    cs = starts[idx]
    cum = 0.0
    bounds = []
    for k, x in enumerate(wl):
        t0 = a + span * cum / total
        cum += weights[k]
        t1 = a + span * cum / total
        bounds.append([t0, t1])
    # snap word boundaries to the nearest real pause when close
    mids = [(s + e) / 2 for s, e in sil if 0.02 < (s + e) / 2 < dur - 0.02]
    for k in range(1, len(bounds)):
        near = min(mids, key=lambda m: abs(m - bounds[k][0]), default=None)
        if near is not None and abs(near - bounds[k][0]) < 0.14:
            bounds[k][0] = near
            bounds[k - 1][1] = near
    for k, x in enumerate(wl):
        words.append({
            "i": len(words) + 1,
            "line": idx + 1,
            "w": x["w"],
            "punct": x["punct"],
            "start": round(cs + bounds[k][0], 3),
            "end": round(cs + bounds[k][1], 3),
        })

WORDS_JSON.write_text(json.dumps({
    "source": TTS_SOURCE,
    "duration": LENGTH,
    "lines": DISPLAY,
    "words": words,
}, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"  words.json: {len(words)} word timings")

# ---------------------------------------------------------------------------
# 3. Vox-style editorial music bed (100 BPM, light percussive + paper rustle)
# ---------------------------------------------------------------------------
random.seed(303)
music = [0.0] * N


def add(start, dur, fn):
    i0, i1 = max(0, int(start * SR)), min(N, int((start + dur) * SR))
    for i in range(i0, i1):
        music[i] += fn((i - i0) / SR)


def sine(f, amp, dur, attack=0.004, release=None, phase=0.0):
    release = release if release is not None else dur * 0.8
    def g(t):
        e = min(1.0, t / attack) if attack else 1.0
        if t > dur - release:
            e *= max(0.0, (dur - t) / release)
        return amp * e * math.sin(2 * math.pi * f * t + phase)
    return g


def pluck(f, amp, dur, decay=9.0):
    def g(t):
        e = math.exp(-decay * t)
        return amp * e * (math.sin(2*math.pi*f*t) + .28*math.sin(4*math.pi*f*t))
    return g


def kick():
    return lambda t: .22 * math.exp(-15*t) * math.sin(2*math.pi*(46+95*math.exp(-30*t))*t)


def noise(amp, dur, decay=22.0, bright=0.0):
    def g(t):
        n = random.uniform(-1, 1)
        return amp * math.exp(-decay*t) * (n + bright*random.uniform(-1, 1))
    return g


def rustle(dur=.5):
    def g(t):
        p = t/dur
        e = math.sin(math.pi*p) ** 1.4
        return .055 * e * random.uniform(-1, 1) * (0.5 + 0.5*math.sin(2*math.pi*13*t))
    return g


def click():
    return lambda t: .10 * math.exp(-90*t) * random.uniform(-1, 1)


BEAT = 0.6  # 100 BPM
ROOTS = [110.0, 87.31, 130.81, 98.0]
CHORDS = [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63],
          [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
BAR = 4 * BEAT
for b in range(int(math.ceil(LENGTH / BAR))):
    t0 = b * BAR
    root, chord = ROOTS[b % 4], CHORDS[b % 4]
    for k, f in enumerate(chord):
        add(t0, BAR, sine(f, .020, BAR, attack=.25, release=.6, phase=k*1.6))
    add(t0, BAR, sine(root/2, .032, BAR, attack=.2, release=.6))
    for beat in range(4):
        t = t0 + beat * BEAT
        if beat % 2 == 0:
            add(t, .26, kick())
        add(t, .32, pluck(root, .085, .32, decay=9))
        if beat % 2 == 1:
            add(t, .10, noise(.075, .10, 20))
        for h in range(2):
            th = t + h * .30
            add(th, .045, noise(.017 if h == 0 else .011, .045, 60, bright=.4))
            add(th, .16, pluck(chord[(beat*2+h) % 3] * 2, .020, .16, 18))

# paper rustle at every line change, camera clicks at polaroid beats
for s in starts:
    add(max(0, s - .18), .55, rustle(.55))
for s in (starts[0], starts[2], starts[6], starts[9], 35.4):
    add(s, .06, click())
# warm ending signature
for i, f in enumerate([440.0, 523.25, 659.25, 880.0]):
    add(35.0, 2.0, sine(f, .042, 2.0, attack=.06, release=1.2, phase=i))
add(36.2, .8, kick())
print(f"  music bed synthesized ({N} samples @ {SR} Hz)")

# ---------------------------------------------------------------------------
# 4. Mix with ducking under the narrator
# ---------------------------------------------------------------------------
vo = [0.0] * N
duck = [1.0] * N
for (num, samples, dur), cs in zip(clips, starts):
    i0 = int(cs * SR)
    for j, v in enumerate(samples):
        if i0 + j < N:
            vo[i0 + j] += v
    end = cs + dur
    a, b, c, d = cs - .16, cs + .06, end + .04, end + .26
    for i in range(max(0, int(a*SR)), min(N, int(d*SR))):
        t = i / SR
        if t < a: k = 1.0
        elif t < b:
            p = (t-a)/(b-a); k = 1 - .55*(p*p*(3-2*p))
        elif t < c: k = .45
        elif t < d:
            p = (t-c)/(d-c); k = .45 + .55*(p*p*(3-2*p))
        else: k = 1.0
        duck[i] = min(duck[i], k)

out = [music[i] * duck[i] * .72 + vo[i] for i in range(N)]
peak = max(abs(v) for v in out) or 1.0
gain = .94 / peak if peak > .94 else 1.0
pcm = array("h", (int(max(-1, min(1, v*gain)) * 32767) for v in out))
with wave.open(str(OUT), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print(f"  wrote {OUT} ({LENGTH:.2f}s, peak {peak:.3f})")
