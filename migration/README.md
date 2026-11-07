# Unity → Godot 4 migration — progress report

This directory is the migration's single source of truth: the audit, the phase status, the decisions,
and the list of what is *not* done. It is deliberately in the same repository as the Unity project,
which is never modified by this work.

**Rule that governs everything below:** a phase is done when its claims are verifiable in CI, not when
the code is written. A count of tests, a commit hash, an artifact — or it is pending.

## Status

| phase | scope | state | evidence |
| --- | --- | --- | --- |
| **1** | repository audit + feasibility | **complete, awaiting review** | [`01-audit.md`](01-audit.md) · [`02-inventory.csv`](02-inventory.csv) (173 files) · [`03-compatibility.md`](03-compatibility.md) · [`04-dependency-graph.md`](04-dependency-graph.md) |
| 2 | Godot project init + Persian spike + headless CI | **not started** | blocked on review of Phase 1 |
| 3 | asset migration (85 sprites, 2 fonts, 11 JSON) | not started | |
| 4 | core gameplay reconstruction (2,607 lines) | not started | |
| 5 | UI, motion, audio, visual reconstruction | not started | |
| 6 | levels + progression | not started | |
| 7 | testing + Android optimisation | not started | |
| 8 | release validation | not started | |

No Godot runtime file exists on this branch. That is the correct state after Phase 1.

## Relationship to draft PR #2 (`feature/godot-migration`)

A parallel draft PR exists — **#2, "Draft: establish independent Godot migration workspace"**, head
`feature/godot-migration`, 2 files (`migration/initial-audit.md`, `godot-port/README.md`). It was not
created by this session; this session is bound to `arena/d42cf39b-ideal` and cannot push to that branch.
The two attempts agree on the essentials and must be **reconciled, not merged blindly**:

| claim | PR #2 | this audit | resolution |
| --- | --- | --- | --- |
| scope | `client/` 196 entries, 176 files | `client/Assets` 173 files | different scopes, both correct: 173 + `ProjectSettings/ProjectVersion.txt` + `Packages/manifest.json` + 1 = 176 |
| JSON count | 12 in `client/` (10 levels, 1 district, 1 package manifest) | 11 content JSON + the package manifest | identical, counted differently |
| tests | "150 tests" (from `docs/art.md`-era prose) | **152** `[Test]` methods, measured | 152 — the prose was stale |
| serialised Unity assets | not stated | **0** scenes/prefabs/materials/shaders/anim/audio | this audit's §1/§3/§6 |
| inventory + dependency map | listed as "next deliverable" | [`02-inventory.csv`](02-inventory.csv), [`04-dependency-graph.md`](04-dependency-graph.md) | delivered here |
| renderer for Android | left open | **Compatibility (GLES3)**, D2 | answered here |
| test framework | left open | **GUT**, D3 | answered here |

Recommendation for the reviewer: keep this directory as the migration record, and reduce
`migration/initial-audit.md` on that branch to a short pointer at [`01-audit.md`](01-audit.md) so there is
one set of numbers. `godot-port/README.md` (the rules for the port directory) is worth keeping as-is —
it says nothing this audit contradicts.

## How to reproduce the audit

```bash
python3 migration/tools/audit.py          # rewrites 02-inventory.csv and prints the counts
python3 migration/tools/audit.py --check  # fails if the CSV is stale
python3 migration/tools/audit.py --json   # the same summary as machine-readable JSON
python3 migration/tools/check_audit.py    # asserts the plan's assumptions still hold
```

Both of the last two run in the `migration audit` job of `.github/workflows/ci.yml` on every push, so
Phase 1's numbers cannot rot: adding a C# file, or a `.unity`/`.prefab`/`.shader` appearing, fails the
build instead of silently invalidating §1, §3 and §8 of the audit.

Standard library only. The script classifies every file under `client/Assets` into
`copy-logic | translate | rebuild | regenerate | import | drop`, and assigns a risk band; those
classifications are what the phases claim against.

## Branch policy — and the one instruction that cannot be followed literally

The task asked for a dedicated `feature/godot-migration` branch. **This session is bound to a single
branch (`arena/d42cf39b-ideal`); creating or switching branches is not permitted here.** The isolation
the instruction is protecting is achieved by *directory* instead:

- `client/` (the Unity project) is **untouched** by every phase — no edits, no deletions, no moves;
- all new work lands in `godot-port/` (the Godot project) and `migration/` (this documentation);
- nothing is ever pushed to `main`; when Phase 2 lands, a pull request to `main` carries the migration,
  and the Unity project remains buildable on `main` exactly as it is today.

If the reviewer can create the branch, the Phase 1 commit applies cleanly to it — it is pure addition
(`migration/` + one CI job). Draft PR #2 already reserves that branch name, so the practical route is a
cherry-pick of this commit onto `feature/godot-migration`.

## Decisions taken, with their reasons

| # | decision | reason | reversible? |
| --- | --- | --- | --- |
| D1 | isolate by directory, not by branch | session branch is fixed; `client/` must stay intact | yes — cherry-pick onto a branch |
| D2 | **Compatibility (GLES3)** renderer on Android | pure 2D, flat vector art, low draw calls, widest device reach, fastest cold start | yes — one project setting |
| D3 | **GUT** for the ported tests | 152 plain assertions; `-s addons/gut/gut_cmdln.gd` runs headless in CI with no editor | yes |
| D4 | autoload singleton for `GameSession` | one instance, every screen and the HUD need it; `AppRoot` is already the sole owner of navigation | yes |
| D5 | generated *and* regenerable: tokens, art catalog | one source of truth (`tokens.json`, `art/manifest.json`); a forked design system is worse than no port | yes |
| D6 | Persian shaping decided by measurement | the repo already owns golden vectors; choosing by preference would be a guess | n/a — a spike |

## Known problems at the end of Phase 1

1. **No working Unity build exists to compare against.** The Unity project has never compiled in this
   environment (no `UNITY_LICENSE`), so the migration's definition of parity is *the 152 tests, the
   design docs and the golden vectors* — not a running original. Recorded as risk R1 in
   [`01-audit.md`](01-audit.md) §10; it is the biggest risk in the project and it is not the port's fault.
2. **No visual reference of the Unity UI.** The layout will be reconstructed from the C# literals
   (415×738 design space) and reviewed on device; a pixel comparison against Unity is impossible here.
3. **The `godot-port/` runtime does not exist yet**, so every claim in this directory is about the
   *source* project.

## What Phase 2 will do, if this audit is approved

1. `godot-port/project.godot` (415×738, canvas_items/expand, portrait, GLES3), one empty `Main.tscn`
   that boots headless and prints a boot line.
2. The Persian spike: golden vectors through `TextServerAdvanced`, diff recorded, path (a) or (b) chosen.
3. CI: parse every `.gd`, import the project headless, run the (still tiny) GUT suite, and fail on a
   missing resource. **No Android build claim** until export templates are configured.
4. The deterministic core ported from `Core/` with its tests, because it is the only part that can be
   proven correct without a screen.
