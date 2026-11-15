# Guild Tycoon — decision log

هر تصمیم با دلیل، تاریخ و پیامدهایش ثبت می‌شود. تصمیم‌های «قطعی» تا وقتی کاربر
تغییرشان ندهد معتبرند و کد باید با آن‌ها بخواند.

| # | Decision | Status | Date |
| --- | --- | --- | --- |
| ADR-001 | Work in `guild/` namespaces on `arena/82a11100-ideal` | Accepted (session constraint) | 2026-11-15 |
| ADR-002 | English-first UI; Persian replaces text only, layout never changes | **Accepted (user directive)** | 2026-11-15 |
| ADR-003 | Money comes only from delivered goods and loot margin | Accepted | 2026-11-15 |
| ADR-004 | Logic lives in `RefCounted`, presentation is a view of it | Accepted | 2026-11-15 |
| ADR-005 | Data tables are GDScript constants, not `.tres` | Accepted | 2026-11-15 |
| ADR-006 | Roadstop code stays until the guild slice is playable | Accepted | 2026-11-15 |
| ADR-007 | Art: procedural kit + replaceable character contract | **Pending** | 2026-11-15 |

---

## ADR-001 — Guild work stays inside `guild/` namespaces on the current branch

**Context.** The brief asks for a new branch `guild-tycoon/prototype` created from
`arena/82a11100-ideal`. This session can only commit to and push
`arena/82a11100-ideal`; creating or switching branches is not possible here.

**Decision.** All new code, scenes, data and assets go into
`scripts/guild/**`, `scenes/guild/**`, `data/guild/**`, `assets/guild/**`,
`tests/suites/test_guild_*.gd`, `tools/guild_*`. No Roadstop file is rewritten.
The Roadstop tree is deleted in one commit at the end of Phase 5.

**Consequences.** The source stays recoverable at `7778d15`; a later
`git branch guild-tycoon/prototype` from any commit on this branch is a one-liner.
Both games coexist temporarily; the guild APK excludes the road files with
`exclude_filter` until the deletion.

---

## ADR-002 — English-first UI, Persian replaces words only

**Directive (user, 2026-11-15).** «بازی انگلیسی و با چیدمان و کلمات انگلیسی ساخته
می‌شود و در صورت انتخاب زبان فارسی فقط کلمات جایگزین می‌شوند و هیچ چیدمانی تغییر
نمی‌کند.»

**Decision.** `GuildLocale` (`scripts/guild/app/guild_locale.gd`) makes this
mechanical:

- English is the base table (`STRINGS`); Persian is a key-for-key override table.
- `layout_direction()` always returns `LAYOUT_DIRECTION_LTR`; `is_rtl()` is always
  false; `alignment()` is always left. There is no mirrored layout to maintain.
- Numbers are Latin digits with thousands separators in both languages, so every
  meter, counter and price keeps its width when the language changes.
- A Persian override that keeps an English placeholder (`{0}`, `{1}`) is enforced
  by a test, so a translation can never drop a number out of a sentence.
- `missing_overrides()` must be empty: no silent fallback to English.

**Consequences.** One layout to design, test and screenshot. Persian text is
shaped correctly by the bundled Vazirmatn font, but it is *text only*: no RTL
mirroring, no right-aligned panels, no flipped button order. Numbers stay Western
digits (a deliberate reversal of Roadstop's Persian digits for exactly this
reason). Roadstop is untouched until it is removed; Guild does not use
`App.layout_direction()`.

---

## ADR-003 — Money has exactly two sources

**Context.** Roadstop's economy printed money from `demand × capacity × price` per
minute, with delivery and taps bolted on. Guild Tycoon's whole point is that the
player's hands move goods.

**Decision.** Gold enters the game only as:

1. a customer payment for a fulfilled order (`sell − 0`), and
2. the margin on loot the guild buys from a returning adventurer and later sells.

No per-minute passive income in Phase 1. Employee automation in Phase 5 may move
items, but only through the same `pick_up → deliver → pay` functions, so no new
money path is introduced.

**Consequences.** Every balance number is traceable to a real transaction; the
economy tests can assert `gold_delta == sum(payments) − sum(purchases)` exactly.

---

## ADR-004 — Logic in `RefCounted`, presentation is a view

**Decision.** Inventory, carry stack, orders, treasury, adventurers, missions and
progression are plain `RefCounted` classes with signals, no `Node` dependency.
`Node3D` code observes them and renders (stack meshes, NPC states, HUD).

**Consequences.** All of it is unit-testable headlessly (the Roadstop suites prove
the pattern), and the "visual stack must equal the real count" requirement becomes
a test, not a promise.

---

## ADR-005 — Data tables are GDScript constants

**Decision.** Items, missions, loot tables, customer types and upgrades live in
`data/guild/*.gd` as `const` dictionaries with static accessors, like
`BusinessData`/`MissionData` today.

**Consequences.** No resource loading, no editor round-trip, tests read them
directly, diffs stay reviewable. Migration to `.tres` later is mechanical if the
project ever needs designer-editable data.

---

## ADR-006 — Roadstop stays until the guild slice plays

**Decision.** No big-bang rewrite. The guild is built alongside; Roadstop keeps
passing tests and producing screenshots. Deletion happens once the guild has its
own tests, its own screenshots and its own APK.

**Consequences.** CI stays green in every intermediate commit, and the source
systems (`App`, `Sound`, `SaveManager`, tests, APK pipeline) can be borrowed with
confidence.

---

## ADR-007 — Art strategy (pending)

**Open question.** No anime characters or fantasy environments exist in the repo,
and this workspace cannot reach asset marketplaces. Options under discussion:

- **A.** Procedural environment kit + replaceable character contract + generated
  2D art (portraits, icons, UI frame). Start now, best possible under the
  constraint.
- **B.** Wait for externally supplied glTF characters/environment.
- **C.** Lean fully on generated 2D art with simple, clean 3D.

Until this is decided, Phase 2 work that does not depend on the answer (player
controller, camera, navigation, hall layout with grey boxes *for measurement only*,
tests) can proceed, but no final-look art is claimed.
