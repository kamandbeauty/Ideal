# Art — the pipeline, the contract, and the brief

The acceptance criterion for this project is blunt: **the graphics must look professional, at the level
of the source game**. That cannot be satisfied by code, and it must not be satisfied by generated
imagery (see §6). So M3 builds the part that *is* engineering — the contract, the import rules, the
placeholder fallbacks, the gates — and hands the drawing to a person with a brief they can work from.

Nothing in this milestone claims the game looks good yet. It claims that the day a file lands, it is
validated, imported, loaded and drawn correctly, and that no screen can ask for a sprite that does not
exist in the contract.

## 1. How art enters the game

```
art/manifest.json                     the contract: id, size, group, required, description, brief
        │  tools/art/art.py --emit
        ▼
Assets/Game/ArtCatalog.gen.cs         generated: the ids the code may ask for
        │
        │  artist exports PNG                          ┌──────────────────────────────┐
        ▼                                             │ missing? → token placeholder │
Assets/Game/Resources/art/<id>.png ──▶ ArtLibrary.Get(id) │ wrong size? → CI fails       │
        │  ArtImportSettings (editor)                  └──────────────────────────────┘
        ▼
SpriteRenderer / Image               screens draw art when it exists, tokens when it does not
```

Three properties fall out of that shape, and they are the reason it is worth the indirection:

- **Art is additive.** A screen never depends on a file existing, so art can arrive one sprite a week
  without a branch, a flag or a broken build.
- **The contract is checked twice.** CI validates the manifest and any committed PNG; the editor
  importer logs when an imported file is the wrong size or is not in the manifest at all.
- **The ids live in one place.** `ArtCatalog.gen.cs` is generated; a rename in the manifest regenerates
  it, and `ArtCatalogTests` fails if the engine grows a piece or an obstacle that the contract does not
  describe.

## 2. Rules the contract enforces

| rule | why |
| --- | --- |
| PNG, with a real alpha channel | Everything composites over a board and a palace plate; a baked background cannot |
| Width and height multiples of 4 | ASTC/ETC block compression needs it; a 830 px plate silently becomes a 832 px blur |
| ≤ 2048 px per side, ≤ 1 MB per file | The install budget is 150 MB and the texture budget is what GPUs actually charge |
| Sprites, not textures | `ArtImportSettings` sets it on import so nobody has to remember |
| No baked text | It cannot be translated, scaled, read by accessibility, or flipped for RTL |
| An id, a size, a description **and** a brief for every entry | An asset without a brief is a guess that gets drawn twice |

```bash
python3 tools/art/art.py                 # report: contract, catalog, what exists, what is missing
python3 tools/art/art.py --emit          # regenerate ArtCatalog.gen.cs
python3 tools/art/art.py --check         # CI: contract valid, catalog current, existing files valid
python3 tools/art/art.py --check --strict  # release gate: every required asset exists and is valid
```

Today: **43 assets in the contract, 10 required, 0 on disk.** The game is playable because every
required sprite has a placeholder: pieces are token-coloured shapes, the palace plate is two bands of
surface, the HUD icons simply do not appear.

## 3. What exists, per screen

| screen | art it will use | placeholder it uses now |
| --- | --- | --- |
| Board | `piece_*` (5), `obstacle_*` (8), `powerup_*` (3–5) | tokens: `Tokens.Piece.*` colours, border tints for obstacles |
| Top bar | `icon_coin`, `icon_potion`, `icon_life` | no icon; the numbers carry the meaning |
| Home | `home_palace` (1024×768) | two bands of `surface`, identical layout |
| Districts | `district_ch01_d1..d3`, `prop_ch01_*` (12) | surface card, task pills |
| Result | `reward_chest` (closed/open), `icon_star` | text only |
| Store | `app_icon` (512×512) | — (nothing to draw in-game) |

## 4. The brief

The full per-asset brief is in `art/manifest.json` — the same file CI validates, so it cannot drift
from what the game asks for. The visual direction is `replica/design/art-direction.md`: Persian-royal,
lapis night and turquoise enamel, gold for reward, ivory type; muqarnas, brick, cypress, tile; no
characters, no Disney.

The four rules that decide whether a set looks like a game or like a mockup:

1. **Silhouette first.** All five stones must be distinguishable in greyscale at 48 px, because that is
   the size they are actually played at. Shape, then colour.
2. **One light, one camera.** The three district plates share a light direction and a horizon, so
   building a district reads as the same place changing.
3. **No baked effects.** Glows, particles, damage states, tints and 9-slice scaling happen in code
   (`BoardScreen`, `UiKit`); a baked glow cannot be animated, tinted or reused.
4. **Respect the layout.** The home plate leaves its left third calm for the level card; the board
   frame must not compete with the pieces. The layout is `docs/ui.md` §3 and it does not bend for art.

## 5. Review gates

- `art.py --check` in CI on every push; `--strict` before a store build.
- `ArtTools → Report missing art` in the editor for the artist's own loop.
- A `_PersianCheck`-style visual pass is **not** enough: every sprite is checked for size and alpha in
  the file itself, and the board is checked at 48 px and at cell size.
- The performance gate is unchanged: 60 fps on a Redmi Note 10, ≤ 150 draw calls, ≤ 150 MB install. The
  board is one texture per piece kind, so batching depends on keeping the pieces in one atlas — that is
  the next pipeline step once the art exists (Sprite Atlas per group, added to `ArtImportSettings`).

## 6. Why no generated art ships

The user asked for graphics at the level of the original, and also accepted the clean-room rule that we
never ship the original's assets. Generated imagery would satisfy neither: it is not authored to a
style guide, it cannot be iterated by an artist, and it tends to look *almost* right, which is worse
than an honest placeholder. Concepts live in `replica/design/concepts/` as reference only; nothing from
there enters `Assets/Game/Resources/art/`. `replica-brand/sweep.py` checks the sweep of what we ship;
a human checks that our art does not resemble theirs.

## 7. What this milestone does not do

- It does not draw anything. There are no sprites in the repository.
- No animation (idle, swap, cascade, chest reveal) — the motion tokens exist, the clips do not.
- No atlas yet: with zero sprites, packing is premature.
- No audio.
