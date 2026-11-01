# Vendored: `nimaone/persian_tts` ("پارسیگو")

Upstream: <https://github.com/nimaone/persian_tts> · pinned at `e834bd6` (main,
2026-09-20) · cloned 2026-11-02.

This is the Persian TTS backend requested for the KAMAND EYE voiceover. Only
the small, source-level parts needed to run the offline ONNX engine are kept
here (the upstream repo intentionally gitignores its model weights):

| File | Origin |
| --- | --- |
| `scripts/tts_onnx.py` | upstream, unmodified — pure-ONNX inference engine |
| `scripts/g2p_onnx.py` | upstream, unmodified — Persian G2P |
| `voices/*.wav` | upstream, unmodified — built-in reference voices (24 kHz mono) |
| `requirements.txt`, `README*.md` | upstream, unmodified |
| `model/` | **not included** — see `model/README.md` |

## Licensing / usage caveat

Upstream documents the underlying weights as:

- `mehdi-hf/pocket-tts-farsi-v2` — **CC-BY-NC-4.0** (non-commercial)
- `mehdi-hf/Homo-GE2PE-Persian-HF` (G2P) — MIT

Because the KAMAND EYE film is a commercial advertisement, check that your
usage of the `pocket-tts-farsi-v2` weights complies with CC-BY-NC-4.0 before
publishing. The vendored Python code itself carries no explicit LICENSE file
in the upstream repo; treat it as "all rights reserved" unless the author
states otherwise.

## How the project uses it

`motion/kamand-eye/audio/generate-vo-persian-tts.py` imports `OnnxTts` from
this directory, generates the 10 diacritized voiceover lines with the female
reference voice `voices/female_narration.wav`, and replaces
`motion/kamand-eye/audio/vo/*.wav`. Then:

```bash
npm run kamand-eye:audio     # rebuild mix.wav with the new clips
npm run kamand-eye:render    # re-mux into 1080p + 4K MP4s
```

The engine is fully offline at runtime (CPU, no GPU, no network) once the
weights are present. The sandbox used for this build cannot reach
`huggingface.co`, so the shipped MP4s currently use the fallback TTS voice;
`model/README.md` has the exact one-line download command for any machine
with normal internet access.
