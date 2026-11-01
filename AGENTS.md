# Agent instructions for the Ideal workspace

## Installed skills

Skills live in `.agents/skills/` (the Agent Skills open standard,
`https://github.com/agentskills/agentskills`). A symlink at
`.claude/skills/motion-graphics` makes the same skill discoverable by Claude
Code and other clients that read `.claude/skills/`.

| Skill | Activate when |
| --- | --- |
| `motion-graphics` | The user asks for a motion graphic, animation, intro/outro, animated title, logo sting, lower third, stat count-up, chart reveal, video overlay, موشن گرافی, or any frame-based visual sequence. |

When a request matches, read `.agents/skills/motion-graphics/SKILL.md` in full
before writing code, and load only the `references/*.md` files the task needs.

## Active campaign: `kamand paper` (30 s paper kinetic reel)

The newest film lives in `motion/kamand-paper/` — read its `brief.md`.
Reference style: `reference/reel-DfNkAVNNVBu.md` + the two client screenshots
(cream paper, black/orange giant Persian type, 3D kraft gift box, white card,
 barcode, orange CTA pill). 720 deterministic frames at 24 fps, `seek(frame)`,
 Estedad/Vazirmatn, bundled audio. Render: `npm run kamand-paper:render`.

An earlier 45 s Persian kinetic ad lives in `motion/kamand-eye/`
(`npm run kamand-eye:render`) and a six-scene CGI commercial in
`motion/kamand-eyebrow-gel/` (`npm run kamand:render`).

### Prior campaign: `kamand eye` (45 s)

The current ad lives in `motion/kamand-eye/` — read its `brief.md` before
editing. Key facts: vertical 9:16, 45 s, 1080 deterministic frames at 24 fps,
`window.__MOTION__.seek(frame)`, Estedad 900 + Vazirmatn fonts bundled locally,
10 Persian voiceover clips + synthesized 120 BPM music mixed into
`audio/mix.wav`, official KAMAND product cutouts in `assets/`
(**never redesign the packaging or logo**), and `?noText=1` support.
Render with `npm run kamand-eye:render` (adds AAC audio); review stills in
`stills/`. VO timecodes are in `audio/vo-script.md`. The requested Persian TTS
backend `nimaone/persian_tts` is vendored in `third_party/persian_tts/` and
wired through `npm run kamand-eye:vo:persian-tts`; its HF weights are absent
here (`huggingface.co` blocked), so shipped audio uses the `voice-00` fallback.

An earlier six-scene 27.6 s commercial remains in
`motion/kamand-eyebrow-gel/` (`npm run kamand:render`).

## Motion graphics workflow

```bash
npm run motion:new -- <slug>       # scaffold motion/<slug>/index.html + brief.md
npm run motion:render -- <slug>    # export out/<slug>.mp4 (needs Playwright + ffmpeg)
npm run motion:preview             # live preview on 0.0.0.0:8080
npm run skills:validate            # validate skill frontmatter
npm run skills:list                # show skills discovered by the skills CLI
```

Scenes must expose `window.__MOTION__` with `fps`, `frames`, `width`, `height`,
and `seek(frame)`. All motion must be deterministic and derived from the frame
number. Generated videos, PNG frame sequences, and `node_modules/` are ignored
by Git; keep only editable sources and briefs in the repository.

## Adding more skills

```bash
npx skills add <owner>/<repo> --skill <skill-name> -a '*' -y
```

The `agentskills/agentskills` repository itself is the specification plus the
`skills-ref` validator, not an installable skill: `npx skills add
agentskills/agentskills --list` reports "No skills found". Use that repo as the
format reference, not as a skill source.

## Language

The project owner writes in Persian. User-facing documentation (README) is in
Persian; skill instructions and code comments stay in English for portability
across agents.
