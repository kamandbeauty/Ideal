# Voiceover script — KAMAND EYE (Persian / Iranian Farsi)

Professional Iranian female voice, warm / friendly / energetic, confident
advertising tone. **Complete vowel marks are kept here and in the TTS input**
to guide correct pronunciation. On-screen display typography intentionally has
no diacritics.

**TTS backend (requested):** `nimaone/persian_tts` — vendored under
`third_party/persian_tts/` and wired through `generate-vo-persian-tts.py`
with the female reference voice `voices/female_narration.wav`.
See `third_party/persian_tts/SOURCE.md` and `model/README.md`.

**Shipped clips:** generated with the Arena `add_voice` Persian female voice
`voice-00` (`fa`). The `persian_tts` ONNX weights (~469 MB) live on
HuggingFace, which this sandbox cannot reach, so the engine could not be run
here; the pipeline is ready and `generate-vo-persian-tts.py` prints the exact
one-time download command. Rebuild on a machine with internet:

```bash
python3 -m pip install -r requirements-persian-tts.txt
# (one-time) hf download Nimaone/pocket-tts-farsi-v2-onnx --local-dir third_party/persian_tts/model/onnx
npm run kamand-eye:vo:persian-tts   # overwrite audio/vo/*.wav
npm run kamand-eye:audio && npm run kamand-eye:render
```

All clips are mono 24 kHz WAV. `make-audio.py` applies pitch-preserving
`atempo` and places them on the timeline below.

| # | Timecode | Clip | Script (with full tashkil) |
| --- | --- | --- | --- |
| 1 | 00:00.45 | `01-hook.wav` | «اَبْروهات هَنوز هَر کُدوم یِه طَرَف میرَن؟!» |
| 2 | 00:05.25 | `02-solution.wav` | «دیگِه وَقْتِشِه یِه فِکری بِه حالِشون بِکُنی!» |
| 3 | 00:12.40 | `03-giahi.wav` | «کامِلاً گِیاهی!» |
| 4 | 00:16.40 | `04-sefidak.wav` | «بِدونِ سَفیدَک!» |
| 5 | 00:20.40 | `05-rizesh.wav` | «بِدونِ ریزِش!» |
| 6 | 00:25.25 | `06-step1.wav` | «اَوَّل اَبْروهات رو تَمیز و خُشْک کُن.» |
| 7 | 00:28.10 | `07-step2.wav` | «مِقْدارِ مُناسِبی از ژِل بَردار.» |
| 8 | 00:30.70 | `08-step3.wav` | «تارهای اَبْرو رو بِه سَمْتِ بالا و بیرون شونِه کُن.» |
| 9 | 00:35.00 | `09-step4.wav` | «و فُرمِ دِلْخواهَت رو بِساز!» |
| 10 | 00:37.60 | `10-final.wav` | «ژِلِ لیفْتِ اَبْرو کَمَنْد؛ زِیباییِ طَبیعی، هَر روز!» |

Music: 120 BPM upbeat electronic advertising bed (four-on-the-floor kick,
claps on 2/4, 16th hats, plucked bass, warm Am–F–C–G pads, arpeggio), scene
impacts, transition risers and a bright end signature. Music is ducked ~55%
under each voice line. Final mix: `mix.wav` (45.5 s, 24 kHz mono).

Rebuild:

```bash
cd motion/kamand-eye/audio && python3 make-audio.py
```
