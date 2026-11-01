# Fonts — where to put the Persian typeface

This folder is empty in git on purpose. A Persian font is a licensed asset; this repository does not
redistribute one, and a 300 KB binary in a content repo is a licensing question waiting to happen.

## What to do once

1. Download **Vazirmatn** (SIL Open Font License 1.1) — https://github.com/rastikerdar/vazirmatn —
   and copy `Vazirmatn-Regular.ttf` (and optionally `-Bold`) into this folder.
2. In Unity: **کاخ شازده → Build UI font**.
   That writes `Assets/Game/Resources/fonts/shazdeh-ui.asset` with a dynamic SDF atlas.
3. Open `Assets/Scenes/_DesignSystem.unity` and look at the Persian sample lines. If they read
   correctly, the font and the shaper agree.

Until step 2 the game still runs: labels fall back to the TMP default font, log one warning, and
Persian will look wrong. That is a missing asset, not a bug — `docs/ui.md` explains what the renderer
is doing and why the text is shaped in C# before it ever reaches TMP.

## Why this font

- It is the font the design tokens were drawn against (`replica/design/art-direction.md`).
- It carries the Arabic Presentation Forms the shaper needs (U+FB50–U+FEFF), so shaped text draws
  without a second shaping pass.
- OFL permits shipping it in a store build; if you do ship it, add its `OFL.txt` next to it and keep
  the copyright line.

Do not commit a font you do not have the right to redistribute.
