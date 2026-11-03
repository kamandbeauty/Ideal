#!/usr/bin/env python3
"""Exact VO alignment from an ASR transcript (content/transcript.json).

    python3 engine/align.py <slug>     (or: npm run story:align -- <slug>)

`transcript.json` is produced by engine/transcribe.py (faster-whisper, word
timestamps). This script replaces the approximate silencedetect timeline with
the REAL sentence boundaries and word times from the recording:

  * one clean line of vo/script.txt = one ASR segment = one scene
  * every subtitle cue starts on the first word actually spoken in it
  * every karaoke word gets its start/end from the recording itself

It writes content/timeline.js, content/words.js, subtitles/<lang>.srt and the
exported SRT. No hand-edited timings exist anywhere in the project.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

CLEAN = re.compile(r"\s+")
PUNCT_BREAK = re.compile(r"[،؛:.!؟…]$")


def srt_time(t):
    h, m = int(t // 3600), int((t % 3600) // 60)
    s, ms = int(t % 60), round((t % 1) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def read_script(path):
    lines = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = CLEAN.sub(" ", raw).strip()
        if line and not line.startswith("#"):
            lines.append(line)
    return lines


def time_mapper(seg):
    """Interpolate a normalized 0..1 position inside the spoken sentence to a real time."""
    words = [w for w in seg.get("words", []) if w.get("start") is not None and w.get("end") is not None]
    words = [w for w in words if seg["start"] - 0.2 <= w["start"] < seg["end"] + 0.2]
    if not words:
        return lambda f: seg["start"] + f * (seg["end"] - seg["start"])

    total = sum(max(1, len(w["w"].strip())) for w in words) or 1
    pts = [(0.0, seg["start"])]
    acc = 0
    for w in words:
        acc += max(1, len(w["w"].strip()))
        pts.append((acc / total, max(pts[-1][1], float(w["start"]))))
    # The last word's point already sits at fraction 1.0 — replace its time
    # with the end of the utterance instead of creating a duplicate point
    # (a duplicate would make at(1.0) return the word's START, not its end).
    if pts[-1][0] >= 1.0 - 1e-9:
        pts[-1] = (1.0, max(pts[-1][1], seg["end"]))
    else:
        pts.append((1.0, max(pts[-1][1], seg["end"])))

    def at(f):
        f = min(1.0, max(0.0, f))
        for i in range(1, len(pts)):
            f0, t0 = pts[i - 1]
            f1, t1 = pts[i]
            if f <= f1:
                if f1 <= f0:
                    return t1
                return t0 + (t1 - t0) * (f - f0) / (f1 - f0)
        return pts[-1][1]

    return at


def word_timings(text, at, start, end):
    words = [w for w in text.split() if w]
    if not words:
        return []
    # Include the spaces in the denominator so the last word lands at 1.0
    # instead of being clamped early (which used to bunch up the final words).
    total = sum(len(w) for w in words) + (len(words) - 1)
    out, acc = [], 0
    for w in words:
        t0 = at(acc / total)
        acc += len(w)
        t1 = at(acc / total)
        t0 = min(max(t0, start), end)
        t1 = min(max(t1, t0 + 0.04), end)
        out.append({"w": w, "t": round(t0, 3), "d": round(t1 - t0, 3)})
        acc += 1  # the space before the next word
    return out


def make_cues(text, timed, max_chars, wrap_chars, sent_start, sent_end):
    """Greedy chunking on word count/characters + punctuation; each cue = max 2 lines."""
    groups, cur, cur_len = [], [], 0
    for word in timed:
        w = word["w"]
        add = len(w) + (1 if cur else 0)
        if cur and (cur_len + add > wrap_chars or PUNCT_BREAK.search(cur[-1]["w"])):
            groups.append(cur)
            cur, cur_len = [], 0
            add = len(w)
        cur.append(word)
        cur_len += add
        if cur_len >= max_chars and not PUNCT_BREAK.search(w):
            groups.append(cur)
            cur, cur_len = [], 0
    if cur:
        groups.append(cur)

    cues = []
    for k, g in enumerate(groups):
        a = g[0]["t"] if k == 0 else g[0]["t"]
        b = sent_end if k == len(groups) - 1 else groups[k + 1][0]["t"]
        cues.append({
            "start": round(min(max(a, sent_start), sent_end), 3),
            "end": round(min(max(b, a + 0.12), sent_end), 3),
            "text": " ".join(x["w"] for x in g),
            "words": g,
        })
    return cues


def main():
    slug = sys.argv[1] if len(sys.argv) > 1 else "next"
    proj = (ROOT / "projects" / slug) if "/" not in slug else (ROOT / slug)
    cfg = json.loads((proj / "config.json").read_text(encoding="utf-8"))
    lang = cfg.get("lang", "fa")
    fps = int(cfg.get("fps", 30))
    tail = float(cfg.get("tail", 1.1))
    sub = cfg.get("subtitle", {})
    max_chars = int(sub.get("maxChars", 40))
    wrap_chars = int(sub.get("wrapChars", 36))

    transcript = json.loads((proj / "content" / "transcript.json").read_text(encoding="utf-8"))
    segments = transcript["segments"]
    lines = read_script(proj / "vo" / "script.txt")
    if len(lines) != len(segments):
        raise SystemExit(
            f"تعداد خطهای متن ({len(lines)}) با segmentهای ویس ({len(segments)}) برابر نیست.\n"
            f"هر خط = یک جمله/صحنه؛ vo/script.txt رو اصلاح کن."
        )

    vo_duration = float(transcript.get("duration") or segments[-1]["end"])
    film_duration = round(vo_duration + tail, 3)
    frames = round(film_duration * fps)

    # Scene bounds are contiguous: the pause BEFORE a sentence belongs to the
    # previous plate (its camera keeps breathing through the silence).
    bounds = []
    for i, seg in enumerate(segments):
        bounds.append([0.0 if i == 0 else round(float(seg["start"]), 3),
                       round(float(seg["end"]), 3)])
    for i in range(1, len(bounds)):
        bounds[i - 1][1] = bounds[i][0]
    bounds[-1][1] = round(vo_duration, 3)

    sentences, cues, words_by_cue = [], [], []
    for i, (line, seg) in enumerate(zip(lines, segments)):
        start, end = bounds[i]
        sentences.append({"i": i + 1, "text": line, "start": start, "end": end})
        at = time_mapper(seg)
        timed = word_timings(line, at, start, end)
        cs = make_cues(line, timed, max_chars, wrap_chars, start, end)
        for c in cs:
            cues.append({"start": c["start"], "end": c["end"], "text": c["text"]})
            words_by_cue.append(c["words"])

    cues[-1]["end"] = round(vo_duration, 3)

    timeline_js = (
        "// GENERATED by engine/align.py from content/transcript.json — do not edit.\n"
        f"export const LANG = {json.dumps(lang)};\n"
        f"export const FPS = {fps};\n"
        f"export const VO_DURATION = {vo_duration:.3f};\n"
        f"export const DURATION = {film_duration};\n"
        f"export const FRAMES = {frames};\n"
        f"export const BLOCKS = {json.dumps([[round(s['start'],3), round(s['end'],3)] for s in segments])};\n"
        f"export const SENTENCES = {json.dumps(sentences, ensure_ascii=False, indent=2)};\n"
        f"export const CUES = {json.dumps(cues, ensure_ascii=False, indent=2)};\n"
    )
    words_js = (
        "// GENERATED by engine/align.py — word times straight from the recording.\n"
        f"export const WORDS = {json.dumps(words_by_cue, ensure_ascii=False)};\n"
    )
    content = proj / "content"
    for name in ("timeline.js", f"timeline.{lang}.js"):
        (content / name).write_text(timeline_js, encoding="utf-8")
    for name in ("words.js", f"words.{lang}.js"):
        (content / name).write_text(words_js, encoding="utf-8")

    srt = "\n".join(
        f"{i+1}\n{srt_time(c['start'])} --> {srt_time(c['end'])}\n{c['text']}\n"
        for i, c in enumerate(cues)
    ) + "\n"
    (proj / "subtitles").mkdir(exist_ok=True)
    (proj / "exports").mkdir(exist_ok=True)
    (proj / "subtitles" / f"{lang}.srt").write_text(srt, encoding="utf-8")
    (proj / "exports" / f"{slug}-{lang}.srt").write_text(srt, encoding="utf-8")

    print(f"align    {slug} · {lang} · {vo_duration:.2f}s voice → {film_duration:.2f}s film / {frames} frames")
    print(f"scenes   {len(sentences)} · cues {len(cues)} · words {sum(len(w) for w in words_by_cue)}")
    print(f"wrote    content/timeline.js · content/words.js · subtitles/{lang}.srt")
    for i, s in enumerate(sentences):
        print(f"  {i+1:2d}  {s['start']:6.2f} → {s['end']:6.2f}  {s['text'][:46]}")


if __name__ == "__main__":
    main()
