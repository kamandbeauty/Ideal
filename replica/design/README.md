# Design system — کاخ شازده

| file | what it is |
| --- | --- |
| `tokens.json` | the single source of truth: colour roles, type scale, spacing, radius, motion, HUD sizes |
| `art-direction.md` | the art brief: pillars, palette, gems, obstacles, power-ups, chapters, cast, UI skin, motion, audio, asset rules, quality gate, honest cost |
| `components.md` | every component from the recon list: variants, sizes, states, tokens, accessibility, which screens, plus the RTL checklist |
| `gen_tokens.py` | generator: `tokens.json` → `client/Assets/Core/Generated/Tokens.gen.cs` |
| `concepts/` | the two generated concept frames (direction only, never shipped) |

## Gates

```bash
python3 .claude/skills/replica-design/contrast.py replica/design/tokens.json   # 19 pairs, 0 failures required
python3 replica/design/gen_tokens.py                                            # regenerate C# after any token change
```

Both run in `.github/workflows/ci.yml`; the second one also fails if the generated file is stale.

## Two deliberate departures from the skill's defaults

- **No `tokens.css` / Tailwind mapping.** This is a Unity mobile game, not a web app — CSS tokens
  would be dead weight. The equivalent artifact is `Tokens.gen.cs`, so code can never drift from the
  token file.
- **The "design system page" is a Unity scene, not Storybook.** M0 ships a `_DesignSystem` scene
  rendering every variant and state in `components.md` with grey-box art; it is re-skinned with real
  art at M2. No screen may invent a control that is not specified there.

## Palette history

The original's colours are not copied: its signature look is a role, not a hex. This palette is ours
(firouzeh turquoise, lapis night, gold leaf, ivory plaster) and `/replica-brand` owns the final values.
Any change to a token value means: rerun contrast, regenerate C#, rebuild the `_DesignSystem` scene.

## Fonts

Vazirmatn (UI) and Estedad (display) — both SIL OFL, both ship inside the app with an in-game
licences screen. No proprietary font is used or embedded. See `art-direction.md` §9 for RTL, Persian
numerals and bidi rules.
