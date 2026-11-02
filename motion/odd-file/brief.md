# THE ODD FILE — brand + production system

> **NOT EVERYTHING IS WHAT IT SEEMS.**

A faceless, premium short-form channel. Nine-by-sixteen, 25–35 seconds, dark
cinema, editorial typography, electric purple. Every episode is a "file": opened,
examined, and left slightly unresolved.

This folder is not a storyboard. It is a working render pipeline: content lives in
`content/episode.js`, narration in `audio/vo/`, picture and sound lock together in
`timeline.js`, and `render.mjs` exports a finished MP4.

---

## 1. Why it works

| Pillar | Promise to the viewer |
| --- | --- |
| Human Psychology | "You do this and you never noticed." |
| Mind-Blowing Science | "Reality is stranger than the headline." |
| Strange Facts | "This is true and almost nobody knows it." |
| Space & Reality | "You are standing on a very small rock." |
| Unexplained Mysteries | "The file was never closed." |

Audience: global English speakers, 18–40, curious, allergic to introductions.

**Never** open with a greeting, a logo animation, or "did you know". Episode one
second is the hook, not a handshake.

---

## 2. Visual system (locked)

### Type

| Role | Face | Notes |
| --- | --- | --- |
| Headline | **Inter Tight 800** | uppercase, `letter-spacing: -0.035em`, `line-height: 0.94`, 112–152 px |
| Emphasis | same, purple | **one** phrase per scene, never a whole sentence |
| Breath / quote | **Instrument Serif italic** | 214 px, used at most once per episode |
| System / HUD | **Space Mono** | 23–27 px, `letter-spacing: 0.24em`, uppercase |

All fonts are bundled locally (`engine/fonts.css` → `node_modules/@fontsource*`).
No CDN, no network at render time, identical output every run.

### Colour

```
#04040a  stage black        #f4f2f9  ink
#6d28ff  electric purple    #a855f7  accent purple
rgba(124,58,255,.6)         purple glow
```

Purple is an *event*, not a wash: one highlighted phrase, one glow pool, one
2 px rule per scene. If everything is purple, nothing is.

### Grid

- Safe area: 88 px side margins, 78 px top HUD inset, 84 px bottom.
- One focal point per scene. Negative space is the layout; do not fill it.
- HUD: file code + category (top), counter + progress rail (bottom). It is the
  "case file" frame that makes every episode feel part of one archive.

### Motion grammar

| Move | Where | Spec |
| --- | --- | --- |
| Word mask rise | every headline | 118% → 0 translateY, 0.6 s, 0.05 s stagger, expo-out |
| Cut punch | every cut | camera 1.022 → 1.000 over 0.42 s |
| Slow push | every scene | 1.000 → 1.035 across the beat |
| Glow breathe | serif / figure beats | single sine over the beat |
| Plate drift | photo beats | 1.06 → 1.00 scale + 24 px parallax |
| Scene fade | head 0.12 s / tail 0.18 s | hard cuts, never cross-dissolves |
| Grain drift | always | deterministic per-frame offset |

Rules: one move per element, no bounce, no spin, no more than two simultaneous
properties. If a viewer notices the transition, the transition is too big.

### Scene vocabulary

`code` (cold open title card) · `statement` (core beat, 1 purple phrase) ·
`serif` (single quiet breath) · `figure` (one number counting up) ·
`plate` (photographic beat) · `tagline` (outro lockup).

Every episode must use **at least four different types** and must never repeat the
same type twice in a row.

---

## 3. Sound system

| Element | Spec |
| --- | --- |
| VO | deep, natural, confident male English; one clip per beat |
| VO level | peak-normalised to −3 dBFS per line, then −14 LUFS integrated master |
| Bed | synthesised sub drone (55 Hz), slow fifth (82.4 / 110.7 Hz), filtered brown air, 120 BPM soft pulse |
| Ducking | sidechain, threshold 0.02, ratio 12, attack 5 ms, release 280 ms |
| Cut impact | 78→44 Hz decaying thud, −8 dB, on every cut after the first |
| Silence | 0.30 s lead, 0.55 s tail per beat — the edit breathes |

The bed is generated from oscillators in `audio/build.mjs`; nothing is licensed,
nothing is stock. It reads as score, not as music.

---

## 4. Timing model (why nothing drifts)

```
audio/vo/b01.mp3 …  →  trimmed, peak-normalised
                    →  probed for exact duration
                    →  timeline.js: { start, dur } per beat
                    →  index.html: beat duration IS scene duration
```

A beat cannot outlast its narration and cannot start before it. Re-record a line
and the whole film re-cuts itself. There is no manual keyframing to break.

---

## 5. Episode pipeline

1. **Topic + claim** — pick one verifiable, non-obvious fact.
2. **Verify** — primary sources only (papers, agencies, institutions). If it
   cannot be verified, replace the claim; never soften it into vagueness.
3. **Script** — hook, curiosity, reveal, payoff in 65–85 words.
4. **Beats** — 6–9 scenes, each with one visual idea and one purple phrase.
5. **Write `content/episode.js`** — beat ids `b01…b09`, scene types assigned.
6. **Record VO** — one clip per beat into `audio/vo/bXX.mp3`.
7. **Build** — `npm run odd-file:audio` → `timeline.js` + `mix.wav`.
8. **Review** — `npm run odd-file:sample` → stills, fix composition.
9. **Render** — `npm run odd-file:render` → 1080×1920 + 2160×3840 MP4.
10. **QC** — checklist below, then publish.

---

## 6. Image prompts (for `plate` beats)

Every prompt must specify: vertical 9:16, cinematic photoreal or sophisticated
editorial, dark base, controlled purple light source, single focal point, deep
negative space in the upper third for typography, **no text, no letters, no logos,
no watermarks**. Vary the subject and the lighting direction per scene; never reuse
one background for the whole episode.

---

## 7. Delivery package (per episode)

1. Episode number + category
2. Three alternative titles
3. Opening hook
4. Full voiceover script
5. Narration with timestamps
6. On-screen typography per scene
7. Visual description per scene
8. Image-generation prompt per scene
9. Motion + transition instructions
10. SFX + music direction
11. English subtitles
12. YouTube description + hashtags
13. QC checklist

---

## 8. QC checklist

- [ ] 25–35 s, 65–85 spoken words, 6–9 scenes
- [ ] New visual information every 2–4 s; no static stretch over 2 s
- [ ] Hook lands before 1.0 s; no greeting, no logo
- [ ] Exactly one purple emphasis per scene; 1–3 highlighted words total
- [ ] Every claim traceable to a primary source; theories labelled as theories
- [ ] Numbers on screen match the number spoken
- [ ] Text fits the 88 px safe area at 1080 px wide (checked by `fitHeading`)
- [ ] No clip over 2.5 s without a visual change
- [ ] VO sits 15–20 dB above the bed; nothing clips (−1.2 dBTP measured)
- [ ] Last frame holds long enough to read the lockup
- [ ] Rendered at 30 fps, 1080×1920 + 2160×3840, faststart, stereo AAC

---

## 9. Files

```
motion/odd-file/
  index.html              stage + HUD
  engine/theme.css        design tokens, type, overlays
  engine/motion.js        deterministic engine + scene vocabulary
  engine/fonts.css        bundled local faces
  content/episode.js      ← the only per-episode file in the edit
  audio/vo/bXX.mp3        narration, one per beat
  audio/build.mjs         trims, normalises, writes timeline.js + mix.wav
  timeline.js             GENERATED — beat starts/durations
  render.mjs              stills + 1080p + 4K export
  audio/make-srt.mjs      captions generated from the same beat times
  subtitles/ep-001.srt    deliverable captions
  episodes/ep-001/        production package + image sheet for the episode
  assets/ep01/            AI stills (originals + graded 1080x1920 plates)
  stills/                 review frames
  exports/                deliverables
```

### Commands

```bash
npm run odd-file:audio    # timeline + mix (after VO clips exist)
npm run odd-file:srt      # subtitles/ep-001.srt, generated from timeline.js
npm run odd-file:sample   # 10 review stills
npm run odd-file:render   # 1080p + 4K MP4 with audio
```

### Shipped episodes

| File | Episode | Runtime | Package |
| --- | --- | --- | --- |
| 001 | Your Memory Is Not Real | 28.8 s | `episodes/ep-001/package.md` |
