# Caption fonts

Every family here ships inside the APK (no runtime download) and is licensed
under the SIL Open Font License 1.1; the licence text for each one is in
`licenses/`.

## How a font gets in

1. The file is downloaded from the upstream OFL release (Persian families come
   from the rastikerdar projects or from `google/fonts`).
2. The Persian coverage is **verified against the font's own cmap**, not assumed
   from the family name: `پ چ ژ گ ک ی` plus a Persian digit (`۱`) must all be
   mapped. This is done with `fontTools`:

   ```python
   from fontTools.ttLib import TTFont
   cmap = TTFont("Amiri-Regular.ttf").getBestCmap()
   assert all(0x067E, 0x06AF, 0x06CC, 0x06F1 ...)
   ```

   That check is what removed *Tajawal* and *Alkalami* from an earlier draft:
   they look Arabic and elegant, but have no Persian letters at all, so a Persian
   caption would have rendered as tofu boxes.
3. The family is added to `pubspec.yaml`, to `CaptionFonts` (`lib/features/effects/caption_fonts.dart`)
   and, if it is a display face, marked `isDisplay: true`.
4. `python3 tools/check-project.py` re-checks that every catalogue family has a
   declared asset, a licence file and a non-truncated TTF.

## Catalogue (24 families, 21 Persian-capable)

| Family | Persian | Style |
| --- | --- | --- |
| Vazirmatn | ✓ | modern sans, the default |
| Estedad | ✓ | geometric sans |
| Sahel | ✓ | humanist sans |
| Samim | ✓ | rounded sans |
| Shabnam | ✓ | soft sans |
| Tanha | ✓ | display |
| Lalezar | ✓ | display |
| Amiri | ✓ | classic Naskh |
| ScheherazadeNew | ✓ | readable Naskh |
| Lateef | ✓ | Naskh |
| Harmattan | ✓ | modern Naskh |
| Almarai | ✓ | geometric |
| IBMPlexSansArabic | ✓ | modern UI sans |
| Mirza | ✓ | elegant broken-stroke text |
| ArefRuqaa | ✓ | Ruqaa calligraphy |
| Katibeh | ✓ | display |
| Jomhuria | ✓ | display |
| Rakkas | ✓ | display |
| Qahiri | ✓ | Kufi display |
| Gulzar | ✓ | Nastaliq |
| Vibes | ✓ | display |
| Archivo Black | – | Latin viral display |
| Bebas Neue | – | Latin condensed |
| Anton | – | Latin heavy |
