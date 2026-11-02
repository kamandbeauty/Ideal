# Terminal — the man with the old suitcase

1080×1920 · 30 fps · **51.6 s** · H.264 + AAC narration, no text anywhere.

Built from the 2026-11-03 briefs and the supplied character sheet, which is now
the design lock: **blue hoodie with a grey backpack**, thin black legs, black
mitts, round white head, huge eyes, one hair tuft.

## The cut

Shot boundaries sit in the pauses between speech segments in the narration,
so a new picture lands when the narrator draws breath.

| # | time | shot |
|---|---|---|
| v1 | 0.0–7.7 | he walks away into the concourse, back to us, bag and case; crowd passing |
| v2 | 7.7–13.4 | he turns, looks up at the hall, then at us |
| v3 | 13.4–18.0 | push in: the face, tired, breath |
| v4 | 18.0–22.9 | he walks on toward the counter, case in hand |
| v5 | 22.9–28.4 | passport control, wide: give, hand over, held |
| v6 | 28.4–33.0 | push to the documents |
| v7 | 33.0–38.5 | his face; the officer gestures the problem |
| v8 | 38.5–44.1 | pull back: papers come back, his head drops |
| v9 | 44.1–48.0 | the windows at dusk, the plane, him alone |
| v10 | 48.0–51.6 | he turns to us and gives the shrug |

## The mouth

He talks. The mouth is not hand-keyed: `scripts/vo-analysis.mjs` reads the
narration WAV, measures per-frame amplitude and vowel colour (Goertzel probe at
six formant frequencies, nearest vowel) and writes one row per video frame. The
figures read that table (`analysis/lipsync.js`, a script tag because `file://`
pages cannot fetch JSON), so mouth, jaw, head bob and brow lift are all the
voice. Silence means a closed mouth and the drawn expression from `FACE`.

## The rig

`RIG` is a skeleton where the feet are 0 and up is negative: head ≈ 28 % of the
height, hoodie ≈ 40 %, leg ≈ 32 % — proportions taken off the sheet. Limbs use
`jointAt()`, a two-bone solver with an explicit bend sign and a maximum bow, so
knees bow outward and elbows bow away from the body; the earlier `ik()` let a
leg fold across the other one.

## Look

The plates are AI renders (photographic style, not photographs). Figures and
plate share one homography (`withPlate`), so a camera move moves both. At the
counter the plate is repainted over the officer from y = 1492 down: the counter
is the mask, so his body is really behind it.

## Files

| path | what |
|---|---|
| `src/index.html` | the whole film: rig, faces, voice, shots, timeline |
| `render.mjs` | `--sample` (10 stills) or all 1548 frames → `/tmp/t1988-frames` |
| `scripts/vo-analysis.mjs` | WAV → per-frame `[energy, mouthOpen, vowel]` JSON + JS |
| `analysis/lipsync.js` | the table the page reads |
| `audio/vo.wav` | the narration, 51.6 s, 24 kHz mono |
| `assets/plates/sh/` | 1080×1920 plates |
| `exports/terminal-scenes-1080p.mp4` | the film, with sound |

Encoding is a separate step, because `render.mjs`'s in-process ffmpeg call
fails in this shell:

```
ffmpeg -framerate 30 -i /tmp/t1988-frames/f-%06d.png -i audio/vo.wav \
  -map 0:v -map 1:a -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -shortest -movflags +faststart exports/terminal-scenes-1080p.mp4
```

## Honest state

- The mouth is derived from amplitude/formants, not phonemes: it reads as speech
  at this scale, but it is not phoneme-accurate.
- The crowd is three walkers, not the hundreds the brief imagines.
- The plates are AI renders. The suitcase is drawn in 2D and carried in his hand.
