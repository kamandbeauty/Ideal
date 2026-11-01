#!/usr/bin/env python3
"""Regenerate the 10 Persian voiceover clips with nimaone/persian_tts.

Uses the vendored pure-ONNX engine (third_party/persian_tts) and its female
reference voice `voices/female_narration.wav`. Output overwrites
`audio/vo/01-hook.wav … 10-final.wav`, which `make-audio.py` then time-stretches
and mixes into `mix.wav`.

Prerequisites (one-time, on a machine with internet):
  see third_party/persian_tts/model/README.md
  python3 -m pip install -r requirements-persian-tts.txt

Usage:
  python3 motion/kamand-eye/audio/generate-vo-persian-tts.py
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
VENDOR = ROOT / "third_party" / "persian_tts"
PKG = VENDOR / "model" / "onnx"
V2 = VENDOR / "model" / "v2"
VO = HERE / "vo"

# Diacritized for correct Iranian-Farsi pronunciation (display typography has
# no diacritics). Keep in sync with audio/vo-script.md.
LINES = [
    ("01-hook.wav",      "اَبْروهات هَنوز هَر کُدوم یِه طَرَف میرَن؟!"),
    ("02-solution.wav",  "دیگِه وَقْتِشِه یِه فِکری بِه حالِشون بِکُنی!"),
    ("03-giahi.wav",     "کامِلاً گِیاهی!"),
    ("04-sefidak.wav",   "بِدونِ سَفیدَک!"),
    ("05-rizesh.wav",    "بِدونِ ریزِش!"),
    ("06-step1.wav",     "اَوَّل اَبْروهات رو تَمیز و خُشْک کُن."),
    ("07-step2.wav",     "مِقْدارِ مُناسِبی از ژِل بَردار."),
    ("08-step3.wav",     "تارهای اَبْرو رو بِه سَمْتِ بالا و بیرون شونِه کُن."),
    ("09-step4.wav",     "و فُرمِ دِلْخواهَت رو بِساز!"),
    ("10-final.wav",     "ژِلِ لیفْتِ اَبْرو کَمَنْد؛ زِیباییِ طَبیعی، هَر روز!"),
]

SEED = 20261102
VOICE = VENDOR / "voices" / "female_narration.wav"


def check():
    missing = []
    if not (PKG / "manifest.json").exists():
        missing.append(f"ONNX package: {PKG} (see model/README.md)")
    for f in ("normalize_fa.py", "tokenizer_ph.model"):
        if not (V2 / f).exists():
            missing.append(f"host file: {V2 / f}")
    if not VOICE.exists():
        missing.append(f"reference voice: {VOICE}")
    if missing:
        print("persian_tts model is not installed yet:\n", file=sys.stderr)
        for m in missing:
            print("  - " + m, file=sys.stderr)
        print("\nOne-time setup (machine with internet):", file=sys.stderr)
        print("  hf download Nimaone/pocket-tts-farsi-v2-onnx "
              "--local-dir third_party/persian_tts/model/onnx", file=sys.stderr)
        print("  see third_party/persian_tts/model/README.md", file=sys.stderr)
        print("\nThe shipped MP4s keep the fallback TTS voiceover until then.",
              file=sys.stderr)
        return False
    return True


def main():
    if not check():
        return 2
    sys.path.insert(0, str(VENDOR / "scripts"))
    sys.path.insert(0, str(V2))
    try:
        import soundfile as sf
        from tts_onnx import OnnxTts
    except ImportError as e:
        print(f"Missing runtime dependency: {e}", file=sys.stderr)
        print("Install with: python3 -m pip install -r requirements-persian-tts.txt",
              file=sys.stderr)
        return 3

    eng = OnnxTts(pkg_dir=PKG, seed=SEED)
    VO.mkdir(parents=True, exist_ok=True)
    for i, (name, text) in enumerate(LINES):
        audio = eng.synthesize_text(
            text, str(VOICE), seed=SEED + i, pace=1.0, mode="pack"
        )
        sf.write(str(VO / name), audio, eng.sample_rate)
        print(f"  {name:20s} {len(audio)/eng.sample_rate:5.2f}s  ({text})")
    print(f"\nWrote {len(LINES)} clips at {eng.sample_rate} Hz into {VO}")
    print("Next: npm run kamand-eye:audio && npm run kamand-eye:render")
    return 0


if __name__ == "__main__":
    sys.exit(main())
