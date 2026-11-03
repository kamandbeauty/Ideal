#!/usr/bin/env python3
"""Optional: rebuild content/transcript.json from the project's VO.

    .venv/bin/python engine/transcribe.py austin-appelbee

Needs faster-whisper and a local CTranslate2 Whisper model (multilingual,
int8). The small model used for the first project was assembled from the
four @skillninja/shortmovie-telop-model-pN npm packages (Whisper-small
CTranslate2 int8, sha256 ca732cb1…), which are reachable from the allowed
npm registry; Hugging Face is NOT needed.

If you already have content/transcript.json (checked in) you can skip this —
align.py reads that file, so the project stays reproducible offline.
"""
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    slug = sys.argv[1] if len(sys.argv) > 1 else "next"
    proj = ROOT / "projects" / slug
    cfg = json.loads((proj / "config.json").read_text(encoding="utf-8"))
    lang = cfg.get("lang", "fa")
    model_dir = os.environ.get("WHISPER_MODEL", "/tmp/whisper-model/model")
    vo = proj / "vo" / f"{lang}.wav"
    if not vo.exists():
        cands = sorted((proj / "vo").glob(f"*.{'wav'}"))
        if not cands:
            raise SystemExit(f"no VO in {proj / 'vo'}")
        vo = cands[0]

    from faster_whisper import WhisperModel
    model = WhisperModel(model_dir, device="cpu", compute_type="int8")
    segments, info = model.transcribe(
        str(vo), language=lang, vad_filter=True, beam_size=10,
        word_timestamps=True, temperature=0,
        initial_prompt=cfg.get("asrPrompt", ""),
    )
    out = {"language": info.language, "duration": info.duration, "segments": []}
    for s in segments:
        out["segments"].append({
            "start": s.start, "end": s.end, "text": s.text.strip(),
            "words": [{"w": w.word, "start": w.start, "end": w.end,
                       "prob": round(w.probability, 3)} for w in (s.words or [])],
        })
        print(f"[{s.start:6.2f} → {s.end:6.2f}]  {s.text.strip()}")
    (proj / "content" / "transcript.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {proj / 'content' / 'transcript.json'}")


if __name__ == "__main__":
    main()
