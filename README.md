# کاخ شازده — Prince's Palace

A clean-room rebuild of Royal Kingdom's core features (match-3 board + kingdom building),
with our own Persian-royal art direction, our own level content, and fixes its players ask for.
Native Android + iOS (Unity). No web client.

| decision | value |
| --- | --- |
| name | کاخ شازده / *Prince's Palace* (working title; trademark check in `/replica-brand`) |
| platform | Android + iOS, Unity 6 + C# |
| language | fa-IR first, RTL; English for store listing |
| scope | core loop: board → potions → district tasks → chest → next district |
| graphics | professional, Persian-royal, never a copy of the original's art |

## Skills

The **Replica** skill pack is installed project-locally in [`.claude/skills/`](.claude/skills)
(MIT — https://github.com/Jakeschincariol/replica-skill). Eleven skills, run in order:

```
recon -> architect -> design -> build -> backend -> test -> diff -> entrepreneur -> brand -> launch -> deploy
```

Each one writes into `replica/` and reads what the previous one wrote.
See [`.claude/skills/README.md`](.claude/skills/README.md) for the map and the tools.

## Progress

| step | file | state |
| --- | --- | --- |
| recon | `replica/recon.md`, `replica/features.csv` | done — 28 screens, 10 flows, 47 features |
| architect | `replica/architecture.md`, `replica/schema.sql` | done — 29 tables, 33 routes, validated SQL |
| design | `replica/design/` — tokens, art direction, components, locked concepts | done |
| build (M0) | `client/Assets/Core` + `Content` + `Game`, `tools/levels/` | done — engine + 10 levels + grey box |
| build (M1) | `Core/{Wallet,Lives,Progression,SaveData}`, `Content/{DistrictParser,SaveCodec}`, `Game/SaveStore` | done — offline economy, save/recover, 3 districts (not yet compiled here) |
| build (M2) | `Core/Text/`, `Game/{AppRoot,GameSession}`, `Game/Ui/` | done — home/board/districts screens, Persian shaping + numerals, Vazir shipped (not yet compiled here) |
| build (M3) | `art/manifest.json`, `tools/art/`, `Game/ArtLibrary.cs`, `Editor/ArtImportSettings.cs` | **done** — 72-asset contract, all 72 sprites drawn by `tools/art/gen_art.py`, `art.py --check --strict` green |
| build (M4) | `Game/Ui/BoardScreen.cs`, `Core/StarRating.cs`, `docs/gameplay.md` | **done** — swipe and tap input, animated swap/clear/settle from the event list, per-goal HUD chips, stars on the result card (not yet compiled here) |
| backend | `replica/schema.sql`, `replica/architecture.md` | schema validated; API not written |
| test | EditMode suite in `client/Assets/Core.Tests` | 140 tests written; runs in CI (no Unity here) |
| diff | `replica/features.csv` | **21.6 / 100** — 16 features partial, 0 must-haves done |
| entrepreneur · brand · launch · deploy | | pending |

## Ground rules

Rebuild features and flows only. Never the original's code, assets, logo, copy,
catalogue or private APIs. Public pages and our own account only. Rebrand before
deploy (`replica-brand/sweep.py` must come back clean).
