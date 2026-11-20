# Guild Tycoon — migration plan (Roadstop Tycoon → Guild Tycoon)

> این سند برنامهٔ اجرایی تبدیل است. خلاصهٔ فارسی در انتها.

Source branch `arena/82a11100-ideal` @ `7778d15` (Roadstop Tycoon 1.0.0, CI green).
Target: Godot 4.7.2, Android (POCO X5 Pro 5G), portrait, 60 FPS target / 30 FPS floor.

---

## 0. Branch policy in this session

The brief asks for a new branch `guild-tycoon/prototype` created from
`arena/82a11100-ideal`, with the source preserved. **This session cannot create,
switch to, or push any branch other than `arena/82a11100-ideal`** — that is a
hard constraint of the environment, not a preference. What is guaranteed instead:

* The Roadstop source is never modified in a destructive way and remains
  recoverable at commit `7778d15` (and on `main` at `cd15fd0`).
* All Guild Tycoon work lands on `arena/82a11100-ideal` in **new namespaces**
  (`scripts/guild/**`, `scenes/guild/**`, `data/guild/**`, `assets/guild/**`),
  so a later `git branch guild-tycoon/prototype` from that commit is a one-liner
  for whoever has branch rights, with no history rewriting.
* Roadstop keeps building and passing tests until the guild slice replaces it, at
  which point the road tree is deleted in a single reviewable commit.

Everything below is written so that the work is branch-agnostic: no file outside
the `guild/` namespaces is rewritten before the switch-over commit.

---

## 1. Target architecture

```
scenes/
  guild/guild.tscn            the playable scene: hall + player + NPCs + HUD
  guild/guild_hud.tscn
  ui/guild_menu.tscn
scripts/
  guild/
    app/                      guild_session.gd (extends Game pattern), guild_state.gd
    player/                   player_controller.gd, player_rig.gd, touch_stick.gd,
                              interaction.gd, carry_stack.gd
    camera/                   follow_camera.gd
    world/                    hall_builder.gd, hall_kit.gd, hall_lighting.gd,
                              nav_builder.gd
    inventory/                inventory.gd, item_stack.gd, warehouse.gd
    economy/                  treasury.gd, pricing.gd, market.gd
    customers/                customer.gd, customer_spawner.gd, order.gd
    adventurers/              adventurer.gd, adventurer_roster.gd, dispatch.gd
    missions/                 mission_board.gd, loot_table.gd
    employees/                employee.gd, automation.gd
    progression/              upgrades.gd
    save/                     guild_save.gd (adapter over SaveManager)
data/guild/                   items.gd, missions.gd, customers.gd, upgrades.gd
assets/guild/                 characters/ props/ materials/ icons/ audio/
tests/suites/                 test_items.gd … test_guild_save.gd
tools/                        guild_smoke.gd, build_hall_kit.py, build_guild_audio.py
documentation/guild-tycoon/   this plan + phase reports
```

Rules carried over from Roadstop (they are why that project stayed green):

1. **Logic is data + `RefCounted`, presentation is thin.** Every rule that can be
   tested headlessly lives in `scripts/guild/**` without touching `Node3D`.
2. **One autoload per concern.** Keep `App`, `Sound`, `Game`; `Game` gains a guild
   session object rather than a fourth autoload.
3. **No placeholder interactions.** A button either changes real state or is not
   shown.
4. **One commit per phase step, CI green** (import → tests → screenshots).

---

## 2. Reuse decisions (from `AUDIT.md`)

| Keep as-is | Adapt | Write new | Drop (later) |
| --- | --- | --- | --- |
| `app.gd`, `l10n.gd`, `sound.gd`, `quality.gd`, `daily_bonus.gd`, `ui_theme.gd` (palette change) | `save_manager.gd` (+v3), `profile.gd` → `GuildProfile`, `service_queue.gd` → order queue, `auto_upgrade.gd` → `automation.gd`, `day_cycle.gd` → hall lighting | player, camera, inventory, warehouse, treasury, customers, adventurers, missions, employees, hall builder, kiosk HUD | `town_view`, `retro_*`, `business_decor`, `customer_flow`, `traffic`, `vehicle_mesh`, `pedestrians`, `town_staff`, `town_state`, `business_state`, `town_data`, `business_data`, `mission_data`(road), `town_events`, `world_map` |

`BusinessData`/`TownState` are referenced by 18 and 16 files respectively; that is
exactly why the guild modules must not import them, and why deletion is deferred to
the end of Phase 5.

---

## 3. Data model (Phase 1)

```gdscript
# data/guild/items.gd
const ITEMS := {
  "slime_gel": {"name_key": "item.slime_gel", "category": "alchemy",
                "buy": 10.0, "sell": 18.0, "icon": "res://assets/guild/icons/slime_gel.png"},
  ...
}
```

* **Item**: `id, category, buy, sell, icon, tier`. Buy price is what the guild pays
  an adventurer; sell price is what a customer pays. Margin = `sell - buy`.
* **Warehouse**: `Dictionary[item_id → int]` + `capacity` (units) + `reserved`
  (picked up but not yet delivered). Invariants: `0 ≤ qty`, `qty + reserved ≤ capacity`,
  no negative, no double-spend.
* **Order**: `{id, customer, item_id, qty, paid: false, promised_price}`. Created by
  a customer, fulfilled by deliveries, paid exactly once.
* **Treasury**: `gold: float` + `pending_cash: float` (money in the player's hands).
  Deposit moves `pending_cash → gold`; both are saved.
* **Adventurer**: `{id, name_key, class, rank (F..S), status: idle|dispatched,
  mission_id, ends_at}`.
* **Mission**: `{id, rank, duration_s, success_p, loot: [{item_id, qty_min, qty_max,
  weight}], fee}`.
* **Language** (`GuildLocale`, `scripts/guild/app/guild_locale.gd`): English base
  table + Persian text-only overrides, Latin numbers, fixed LTR layout (ADR-002).
* **Save v3**: `{version: 3, gold, warehouse, reserved, orders, adventurers,
  dispatch, upgrades, day, streak, last_seen}` + `SaveManager` migration chain
  `v1 → v2 → v3` (v1 = Roadstop single town, v2 = profile, v3 = guild). Migration
  refuses only data it cannot map, and says so in the log.

---

## 4. Systems in detail

### 4.1 Player controller (`scripts/guild/player/`)

* `CharacterBody3D`, capsule radius 0.35, height 1.7, walk 2.2 m/s, run 4.2 m/s,
  acceleration 12 m/s², deceleration 16 m/s², rotation slerp 12/s.
* Input: virtual joystick (dead zone 0.15, max radius 90 px, appears where the thumb
  lands inside the left third), plus WASD/arrow keys on desktop, plus a single
  action button whose verb changes with context ("Pick up", "Deliver", "Deposit",
  "Open board").
* Animation state machine: `idle → walk → run → pickup → carry → deliver →
  receive → deposit`, driven by speed and interaction flags; procedural poses in
  Phase 1, `AnimationTree` hooks in place.
* `CarryStack` (logic, testable): `pick_up(item_id, qty)`, `take(item_id, qty)`,
  `count()`, `capacity` (upgradeable), `is_full()`. Emits `changed` so the 3D view
  (pooled meshes, one per unit, max 12) mirrors the real count. **The view can never
  invent units the logic does not have.**

### 4.2 Camera (`scripts/guild/camera/follow_camera.gd`)

Spring-follow (damping 8), pitch 36°, yaw free, distance 9–20 m with pinch, orbit by
horizontal drag on the right half, `SpringArm3D` collision (radius 0.3), clamp to
the hall bounds, `Engine.max_fps` untouched.

### 4.3 Hall (`scripts/guild/world/`)

Procedural modular kit: `hall_kit.gd` exposes `wall()`, `floor_tile()`, `beam()`,
`shelf()`, `counter()`, `banner()`, `chandelier()`, `carpet()`, `doorway()`; the kit
merges meshes per material to keep draw calls low. Zones marked with `Marker3D`:
entrance, reception, mission board, waiting area, warehouse, trading counter, shop
floor, treasury, staff area. `nav_builder.gd` produces a hand-authored
`NavigationRegion3D` polygon set matched to the hall layout (deterministic, no bake
step in CI).

Lighting: one directional "window" light + 4–6 pooled point lights (candles,
chandelier, treasury) + emissive runes; no shadows from point lights on Low.

### 4.4 Customers (`scripts/guild/customers/`)

`customer.gd` = state machine `enter → browse → order → wait → pay → leave` with
`NavigationAgent3D`; spawner respects `Quality.npc_budget()`; five types
(Warrior, Mage, Archer, Rogue, Knight) differ by palette, silhouette props and
patience. Payment goes through `Treasury`; a customer never pays twice and never
pays without an order.

### 4.5 Adventurers & missions (`scripts/guild/adventurers/`)

`adventurer_roster.gd` holds F..S ranks; `dispatch.gd` sends one to a mission;
`ends_at` is derived from `Time.get_ticks_msec()` monotonic time so a device clock
change cannot shortcut it (fixes `REVIEW.md` §3.2 for the new game). On return:
loot roll from the mission table → offer → guild pays `buy × qty` → items enter
`warehouse` (capacity-checked).

### 4.6 Economy

The only sources of gold: customer payments and mission **net** margin. The only
sinks: buying loot, upgrades, restock. No per-minute passive income in Phase 1; an
"employee automation" upgrade in Phase 5 may auto-deliver, but it moves items
through the same functions (no free money path).

Anti-exploit tests: no negative warehouse, no double payment, no delivery without
stock, no sale without order, deposit ≤ carried cash, save/load mid-carry restores
the same numbers.

### 4.7 UI

Portrait, thumb-reachable: top bar (gold, reputation, warehouse meter, active
customers, active missions), bottom-left joystick, bottom-right action button, right
column for the shop/mission buttons and settings. Panels slide from the right and
never cover the joystick or the action button.

**Language policy (ADR-002):** the UI is authored in English and never mirrors.
Persian replaces words only - `GuildLocale.layout_direction()` is always LTR,
`alignment()` is always left, and numbers stay Latin with thousands separators in
both languages, so no panel, meter or button ever changes size or position when the
language changes. `tests/suites/test_guild_locale.gd` enforces a full override
table, identical placeholders and an unchanging layout. Typography: Vazirmatn
(already bundled, shapes Persian correctly) + generated fantasy UI art.

---

## 5. Phase plan and exit criteria

### Phase 1 — audit and branch *(this turn)*
Deliverables: `AUDIT.md`, this plan, branch policy note.
Exit: audit reviewed; the branch constraint acknowledged; no gameplay code touched.
*(Branch creation itself is blocked in this session — see §0.)*

### Phase 2 — player, camera, hall, mobile controls
Deliverables: `guild.tscn`, `player_controller.gd`, `follow_camera.gd`,
`touch_stick.gd`, `hall_builder.gd` (full hall with all nine zones),
`hall_lighting.gd`, `guild_hud.gd` skeleton, `tools/guild_smoke.tscn` capturing
`g0-hall`, `g1-walk`, `g2-camera-turn`.
Exit: the player walks in the hall, the camera follows/orbits/zooms, joystick + zoom
work on touch, 8 automation tests + screenshots in CI, APK builds.

### Phase 3 — warehouse, carry, orders, treasury
Deliverables: `inventory.gd`, `warehouse.gd`, `carry_stack.gd`, `order.gd`,
`treasury.gd`, customer walk-in with **scripted** order in Phase 3 (full AI in 4),
pickup/deliver/deposit verbs, visible stacks, HUD meters, save v3.
Exit: acceptance items 3–11 of the brief demonstrated in screenshots and covered by
`test_items`, `test_warehouse`, `test_carry`, `test_orders`, `test_treasury`.

### Phase 4 — adventurers, mission board, loot
Deliverables: board UI, roster, dispatch timers, loot tables, purchase flow, five
customer types with navigation, mission simulation tests.
Exit: an adventurer is dispatched, returns with loot, the guild buys it, a customer
buys the item with the player's hands; `test_adventurers`, `test_missions_sim`,
`test_customers`.

### Phase 5 — employees, upgrades, polish, Roadstop removal
Deliverables: upgrade tree (carry, speed, warehouse, hands, deposit), employee
automation through the same APIs, daily chest, reputation, generated UI art, full
localisation, Roadstop deletion commit, `main.tscn` → guild.
Exit: complete loop playable, 15+ suites green, screenshots regenerated, `REVIEW.md`
updated.

### Phase 6 — Android, profiling, regression
Deliverables: package rename (`com.guildtycoon.game`), icons, `apk.yml` for Guild,
on-device profiling notes, quality presets tuned, release build.
Exit: APK on the target phone at 60 FPS with 30 FPS floor, all tests green.

---

## 6. Performance budget (POCO X5 Pro 5G)

| Budget | Low | Medium | High |
| --- | --- | --- | --- |
| Draw calls | ≤ 60 | ≤ 110 | ≤ 160 |
| Dynamic lights | 3 | 5 | 6 |
| Shadow casters | sun only, 1024 | sun + chandelier, 2048 | 3 lights, 2048 |
| NPCs (customers + walkers) | 6 | 12 | 18 |
| Carry meshes | 8 | 12 | 16 |
| FPS cap | 30 | 60 | free |
| MSAA | off | off | off (2D AA only) |

Pooling: every NPC and every carried item mesh comes from a pool; no `instantiate`
in the loop; no per-frame allocations in the logic classes (verified by review).

---

## 7. Verification loop for every phase

1. `gdlint scripts tests tools` + per-file parse.
2. `python3 -m gdtoolkit` check on changed files (local), CI for the real import.
3. Headless tests (new suite per system).
4. `guild_smoke` screenshots on xvfb; previews committed by CI.
5. APK build on the branch (`[apk]` in the commit message) with the APK inspector
   reporting package/version/ABI.
6. Phase report: branch, commit, files created/modified, reused, replaced, tests,
   results, open problems, next step.

---

## 8. Blockers and open questions

1. **Branch creation** — cannot be done from this session (§0).
2. **Character/environment art** — no anime characters or fantasy kit exist and no
   asset source is reachable from this workspace (`AUDIT.md` §5). Phase 2 proceeds
   with the procedural kit + replaceable character contract; the "premium" leap
   needs supplied glTF assets.
3. **Toon shading in Compatibility** — to be verified by a screenshot before the
   art direction depends on it.
4. **Namespace of the data tables** — plan uses GDScript const tables (testable,
   no resource loading); the brief's `data/` folder can host them as GDScript.

---

## 9. Persian summary

- **شاخه:** در این نشست نمی‌توانم شاخهٔ جدید بسازم؛ همهٔ کار روی
  `arena/82a11100-ideal` می‌ماند، ولی در پوشه‌های جدا (`scripts/guild`,
  `scenes/guild`, `data/guild`, `assets/guild`) تا ساختن شاخهٔ `guild-tycoon/prototype`
  از همین کامیت یک دستور ساده باشد و تاریخ بازنویسی نشود.
- **قابل استفادهٔ مستقیم:** ذخیره/پشتیبان (با نسخهٔ ۳ و مهاجرت)، تنظیمات/RTL/ترجمه،
  صدا، کیفیت، جایزهٔ روزانه، صف ظرفیت، تست‌ها، پایپ‌لاین APK.
- **بازنویسی:** اقتصاد «درآمد در دقیقه» جای خود را به فروش واقعی کالا می‌دهد؛
  ویوی شهر/جریان خودرویی/دوربین/محیط حذف و بازنویسی می‌شوند.
- **مسیر اجرا:** فاز ۲ (بازیکن، دوربین، سالن، کنترل موبایل) → فاز ۳ (انبار، حمل،
  سفارش، خزانه) → فاز ۴ (ماجراجو، میسیون، غنیمت) → فاز ۵ (کارمند، ارتقا، پولیش،
  حذف رودستاپ) → فاز ۶ (اندروید و پروفایل).
- **بدون بازیکردن با کلمات:** هر فاز فقط وقتی «تمام» اعلام می‌شود که تست و
  اسکرین‌شات CI و بیلد APK داشته باشد.

---

## 6. Progress log (updated as slices land)

| Slice | What really exists | Proven by |
|---|---|---|
| 1 | audit, branch rules, ADRs 001–007 | `AUDIT.md`, `DECISIONS.md` |
| 2a | Persian-first locale layer, both directions, no mirrored layout | `test_guild_locale` (10 methods) |
| 2b | procedural hero rig, 6 styles, 8 poses, carry/stack anchors | `test_guild_rig` (9) |
| 2c | controller + follow camera, verbs timing, hall with nine zones, generated navmesh | `test_guild_player`, `test_guild_hall` (8 + 9) |
| 3a | economy: items, buy/sell prices, treasury, stock, orders, payment | `test_guild_economy` (12) |
| 3c | customers that **walk**: navmesh route from the door, a four-place queue, the counter order belongs to the front of the line, a served customer walks out and the line steps up, an ignored one gives up; decoration pass (wall bands, zone floor lines, patterned rug, wall sconces, rune circle, violet fill light) | `test_guild_customers` (8), captures `22-guild-customers-walk` / `23-guild-customers-order` |
| 3e | the guild's own save file: vault, warehouse, hands and roster, with a backup copy, a version guard that refuses whole, and offline time that advances the same mission clock (capped at eight hours) | `test_guild_save` (8), report line `save exists=... cash=14 stock=13 roster=5` |
| 3f | the board screen: every job with rank, fee, time and loot table, the member the guild would send, refusals with a reason, opened from the missions fact in the HUD; Persian moves no rectangle | `test_guild_board_panel` (6), captures `27-guild-board-en` / `28-guild-board-fa` |
| 3d | the mission board: a four-job table with ranks, fees and loot tables; a five-person roster; dispatch debits the vault, the clock runs, the pack comes home, and buying it pays the buy price into the warehouse; the HUD's mission counter and the board's sign read the desk; `data/**` added to the CI path filter (a data-only fix never ran the check) | `test_guild_missions` (8), captures `24-guild-board` / `25-guild-loot-bought` |
| 3g | the guild scene itself: `scenes/guild.tscn` + `scripts/guild/game/guild_game.gd` builds the hall, the master, the four stations, the queue and the HUD; the app boots into it (`START_IN_GUILD` in `scripts/main.gd`); saving every 30 s, on Esc and on leaving the scene; a new guild starts with 60 gold and six goods, an old one loads and its expeditions come home | `test_guild_game` (7), captures `29-guild-scene` / `30-guild-walking`, report line `GUILD: ready ...` |
| 3b | touch HUD: facts bar, joystick, contextual action button, toast, language pill; world signs follow the language | `test_guild_hud` (7), captures `20-guild-hud-en` / `21-guild-hud-fa` |

Still open, in this order: upgrades (carry, speed, warehouse, hands, deposit) and
employees, the punishment side of the loop (a customer who leaves angry costs
reputation), the real art pass (imported or authored meshes, hair, faces, fabric),
save/load for the guild state, and finally Roadstop's removal.

What the loop proves today, from the play-through report: `loop stock=13 vault=14
reputation=3.7 last={verb: buy_loot, amount: 32}` - a fee of 8 and a pack worth 32
left the vault, four items entered the warehouse, and the mission's reputation came
home. Nothing in that sentence is decorative.

Note on the HUD: the action button is contextual but the *player* still has to stand
at the station; there is no "tap a customer to serve" shortcut yet, and the mission
board is a labelled but inert zone.
