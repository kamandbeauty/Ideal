# Architecture: کاخ شازده (working title: Prince's Palace) — a rebuild of Royal Kingdom's core features

Input: `replica/recon.md` + `replica/features.csv` (47 rows: 22 must / 13 should / 5 could / 7 skip).
Schema: `replica/schema.sql` — 29 tables, 2 views, 10 enums. Validated by executing it in Postgres
(PGlite, Postgres-compatible) on 2026-11-01: creates clean, the append-only ledger trigger fires,
the lazy lives view returns the right number.

## Decisions locked by the user (2026-11-01)

| decision | value |
| --- | --- |
| name | **کاخ شازده** — English store title *Prince's Palace* (working title; trademark + domain checks belong to `/replica-brand`) |
| platform | **native Android + iOS**, no web client |
| graphics bar | "professional, at the level of the original" — treated as a hard requirement, budgeted below |
| scope | the core-loop slice from recon (17 of 28 screens), everything social/live-ops marked `skip` |
| language | **fa-IR primary, RTL**, English as a store-listing fallback — every screen is designed RTL-first, Persian numerals in UI |

## Stack

| layer | choice | why |
| --- | --- | --- |
| client | **Unity 6 LTS + C#**, URP 2D, Addressables | the only realistic way to ship Royal-Kingdom-grade 2D animation, VFX and a 60 fps board on both stores with one codebase; Spine/2D animation and the asset pipeline are mature here |
| board engine | plain C# assembly (`Shazdeh.Core`), no `UnityEngine` references | deterministic, unit-testable, replayable server-side; the engine is the risky part, so it must not live inside scene code |
| backend | **Node 22 + TypeScript + Fastify**, one service | same language as nothing else here, but boring, fast to write, and the whole API is ~33 routes |
| database | **Postgres 15+** (Neon or Supabase) | schema in `replica/schema.sql`; server-authoritative wallet, append-only ledger, level content as `jsonb` |
| ORM | Drizzle | typed SQL, migrations in the repo, no magic |
| cache/locks | Redis (Upstash) | rate limits, attempt locks, leaderboard later; not a source of truth |
| auth | guest device token first, then **Google Play Games / Game Center / Sign in with Apple** | matches the original (guest → provider link) and keeps the first session account-free |
| payments | **RevenueCat** over StoreKit 2 / Play Billing 7 | receipts, restore, refunds and webhooks in one place; still server-verified before any grant |
| push | FCM + APNs via a thin queue | lives-refilled and "new levels" notifications only |
| content/CDN | Cloudflare R2 + signed URLs | Addressables bundles, level JSON, episode video |
| jobs | Fly Machines cron (or Inngest) | ledger reconcile, stale attempts, GDPR purge, level batches |
| hosting | Fly.io or Render, one region near the players | one service, one database, no microservices |
| logging | OpenTelemetry → Grafana Cloud | one trace per attempt makes anti-cheat investigations cheap |

Rejected on purpose: web client (user said no), a Unity-hosted backend (Backend-as-a-Service game
SDKs), microservices, and a client-side wallet.

## Client layout

```
client/
  Assets/
    Core/            Shazdeh.Core.asmdef      board engine, RNG, goals, power-up matrix, gravity,
                                              dead-board detection, booster effects, scoring.
                                              NO UnityEngine. Deterministic: same seed + same move
                                              list = same board. Tested with NUnit.
    Game/            Shazdeh.Game.asmdef      board view, input, FX, camera, audio
    Meta/            Shazdeh.Meta.asmdef      home kingdom, tasks/districts, world map, shop, settings
    Net/             Shazdeh.Net.asmdef       API client, retry, offline queue, token refresh
    Content/         ScriptableObjects + JSON level cache (bundled fallback, CDN override)
    Art/             Addressables groups per kingdom; nothing loaded twice
  Packages/          URP, Addressables, Input System, TextMeshPro, Newtonsoft, UniTask
  ProjectSettings/
```

Rules that keep this maintainable:

- The client never decides currency. Every potion, coin, life and reward comes from a server
  response; the client only animates the number it was given.
- Attempts are server-seeded. The server issues `seed` at `POST /v1/attempts` and can replay the
  submitted move log through the same `Shazdeh.Core` rules on the server (C# or a TS port used only
  for verification) to catch fake wins.
- Offline: a level already downloaded can be played offline; the attempt is queued and finished
  lazily on reconnect, with the server deciding the reward. If the queue disagrees with the server,
  the server wins and the client shows a "progress updated" dialog.
- Localization from day one: all strings through one table, RTL layout flips, Persian digits, no
  hard-coded English widths inside buttons.

## Schema

29 tables, 2 views, 10 enums — full DDL in `replica/schema.sql`.

Access rules: **no client SQL access at all.** The mobile client only talks to the API; the API
connects with one service role. There is no PostgREST/Supabase public schema, so no row level
security — instead every query goes through a data layer that takes `player_id` from the JWT as its
first argument. The exceptions that are enforced in the database itself, because a bug there costs
real money:

- `players.coins/potions >= 0` and `lives >= 0` checks — no negative wallet, ever.
- `ledger_entries` is **append-only** (trigger raises on UPDATE/DELETE) and `ledger_drift` lists any
  player whose wallet and ledger disagree, so a nightly job can shout.
- `transactions (store, store_transaction_id)` unique — a replayed RevenueCat webhook cannot double-grant.
- `chest_grants (player_id, source, source_id)` unique — one chest, one claim.
- `task_completions (player_id, task_id)` primary key — the potion sink cannot double-charge.
- `idempotency_keys (player_id, key)` — every wallet route is retry-safe.
- `attempts.replay_hash` + `attempt_moves` — a win is verifiable.

Lives are **computed, not scheduled**: `player_wallet.lives_now` derives refills from
`lives_updated_at` (one per 30 min, cap `max_lives`), so there is no refill job to drift or miss.
Any write that touches lives first materialises `lives_now`.

Entities → tables: Player→`players`/`player_settings`, Level→`levels`, Attempt→`attempts`/`attempt_moves`,
BoardCell/PowerUp/Item→`levels.board`+`levels.goals` (content, not rows), Booster→`booster_catalog`/
`booster_inventory`, Kingdom→`kingdoms`, District→`districts`/`district_progress`, Task→`tasks`/
`task_completions`, Chest→`chest_grants`, Episode→`episodes`/`episode_views`, MagicPot→`magic_pots`/
`magic_pot_progress`, Product/Transaction→`products`/`transactions`, Telegram/analytics → OTel + `admin_actions`.

## API

One table per recon flow. `Idempotency-Key` is required on every route marked ⚿.

| # | method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `POST /v1/auth/guest` | create or resume the player bound to this install | public | install_id, platform, app_version | tokens, player | F01 |
| 2 | `POST /v1/auth/refresh` | rotate access/refresh tokens | public | refresh_token | tokens | — |
| 3 | `POST /v1/auth/link` | attach Google Play Games / Game Center / Apple identity | player | provider, subject_token | player | F10 |
| 4 | `POST /v1/auth/restore` | sign in with a provider, return that player's progress | public | provider, subject_token, install_id | tokens, player, progress | F10 |
| 5 | `DELETE /v1/me` | soft-delete + queue 30-day purge | player | confirm_phrase | 202 | F10 (S20) |
| 6 | `GET /v1/bootstrap` | home screen in one call: wallet (with `lives_now`), level, kingdom, district, catalog versions, flags | player | — | state | F02 F04 F05 |
| 7 | `PATCH /v1/me` | display name, avatar | player | display_name?, avatar_id? | player | S21 |
| 8 | `PUT /v1/me/settings` | sound, music, haptics, push | player | 4 booleans | 204 | S20 |
| 9 | `POST /v1/me/push-token` | register FCM/APNs token | player | token, platform | 204 | — |
| 10 | `GET /v1/levels/next` | next level + pre-level card data | player | — | level, boosters, lives | F02 S05 |
| 11 | `POST /v1/attempts` | start an attempt, issue the seed | player | level_id, pre_boosters[] | attempt_id, seed, level, expires_at | F02 |
| 12 | `POST /v1/attempts/{id}/moves` | append a batch of moves (anti-cheat heartbeat) | player owns attempt | moves[] | accepted, moves_left | F02 |
| 13 | `POST /v1/attempts/{id}/finish` ⚿ | award potions/coins, save progress, lose a life on fail | player owns attempt | result, moves_used, boosters_used, replay_hash | wallet, rewards, progress | F02 F03 |
| 14 | `POST /v1/attempts/{id}/extra-moves` ⚿ | buy +5 moves, price ladder per attempt | player owns attempt | — | wallet, moves_left, next_price | F03 |
| 15 | `POST /v1/attempts/{id}/abandon` | quit mid-level, no reward | player owns attempt | — | 204 | F03 |
| 16 | `POST /v1/lives/buy` ⚿ | refill to max for coins | player | — | wallet, lives_now | F04 |
| 17 | `GET /v1/boosters` | catalog + owned counts | player | — | boosters[] | F09 |
| 18 | `POST /v1/boosters/{kind}/buy` ⚿ | buy 1–5 boosters with coins | player | qty | wallet, inventory | F09 |
| 19 | `GET /v1/world` | kingdoms, districts, completion state | player | — | world | F07 |
| 20 | `GET /v1/districts/{id}` | tasks, potions needed, progress | player | — | district | F05 |
| 21 | `POST /v1/tasks/{id}/complete` ⚿ | spend potions, return the build animation payload | player | — | wallet, task, from/to asset | F05 |
| 22 | `POST /v1/districts/{id}/complete-all` ⚿ | the "Do it" button | player | — | wallet, completed_tasks[] | F05 |
| 23 | `POST /v1/districts/{id}/chest` ⚿ | claim the district chest | player | — | rewards, wallet | F05 |
| 24 | `GET /v1/episodes/{id}/url` | signed media URL | player | — | url, expires_at | F07 |
| 25 | `POST /v1/episodes/{id}/viewed` | mark watched | player | — | 204 | F07 |
| 26 | `GET /v1/products` | IAP catalog with store prices | player | — | products[] | F08 |
| 27 | `POST /v1/purchases` ⚿ | verify with RevenueCat, then grant | player | product_id, store, store_transaction_id | wallet, inventory | F08 |
| 28 | `POST /v1/purchases/restore` ⚿ | re-grant any unclaimed transaction | player | — | restored[] | F08 |
| 29 | `GET /v1/config` | remote flags, ETag-cached | public | — | flags, catalog_versions | — |
| 30 | `GET /v1/health` | liveness + db + redis | ops | — | status | — |
| 31 | `POST /admin/levels/batch` | publish a level batch (operator token) | admin | batch_no, levels[] | batch | content |
| 32 | `POST /admin/players/{id}/grant` | support comp, always ledgered | admin | currency, amount, reason | ledger entry | support |
| 33 | `GET /admin/drift` | players whose wallet ≠ ledger | admin | — | rows | ops |

Webhooks in: `POST /v1/webhooks/revenuecat` (grant / refund / transfer; signature-verified,
idempotent on `store_transaction_id`). Webhooks out: none.
Jobs: `ledger-reconcile` nightly → alerts on `ledger_drift`; `attempts-sweep` hourly → close attempts
open >24h as `quit`; `gdpr-purge` daily → hard-delete players soft-deleted >30d; `level-batch` monthly;
`push-dispatch` every 5 min for lives-refilled and release notifications.

## The parts that bite

- **Determinism vs. cheating.** Client-side boards are client-side. Fix: server seed, move log,
  server replay of any suspicious win (top percentile move efficiency, impossible move count, clock
  skew), and rewards granted only after `finish` — never from the board.
- **Idempotency.** Store webhooks arrive twice, mobile retries on flaky networks, users double-tap
  "buy". Every wallet route takes a key; the unique constraints above are the second line of defence.
- **Races.** Two `finish` calls on one attempt (phone + tablet), `complete-all` racing a single
  `complete`, double chest claim. Fix: `select … for update` on the player row for any wallet write,
  attempt row locked on finish, and the unique constraints catch the rest.
- **Lives and clocks.** Timers are computed on the server in UTC; the client shows a local countdown
  and must never be trusted. Device clock skew is displayed, not obeyed.
- **Offline play.** Queue, reconcile, and never let an offline attempt grant currency before the
  server agrees. The player can lose a "won" level to reconciliation once — cheap compared to an
  exploitable wallet.
- **Art and download size.** Royal-Kingdom-grade art does not fit in an APK. Play Asset Delivery +
  Addressables: base install ≤150 MB, kingdom bundles streamed on first entry, one atlas per board
  screen. Budget the pipeline before the art (below).
- **Store rules.** In-app purchases with random items → the "random items" disclosure and a rating
  change; Apple's guideline 3.1.1 (no external purchase links), Play's billing policy, and a
  purchase-restore path that actually works on a new device.
- **GDPR / account deletion.** The original ships an account-deletion article; we ship a real
  `DELETE /v1/me` with a 30-day purge, export on request, and no personal data in analytics logs.
- **Push deliverability.** APNs tokens expire, FCM collapses messages. Push is a nicety, never a
  dependency of progression.
- **Content ops.** Level content lives in `levels.board` jsonb + Addressables keys. A bad level must
  be fixable server-side without a store review, so it is data, not code.

## Graphics: the bar, the pipeline, the honest cost

The user's requirement — "professional, at the level of the source" — is the largest line item in
this project, larger than the engine. Royal Kingdom is #3 top-grossing puzzle with 100M+ installs
(Play Store, 2026-10-16); its art quality is a competitive moat, and it is produced by a studio-scale
2D team. We cannot generated-image our way to it, and we must not copy a single asset from it.

**Art direction (ours, not theirs):** Persian royal — Safavid/Qajar tilework, turquoise-and-lapis
palette, gold leaf, muqarnas arches, Persian miniature perspective. This is deliberately *not* the
European cartoon-castle look, so the brand is defensible and the IP gap is visible from the first frame.
The cast is ours: a young prince, a court architect, a vizier, and a rival. `replica-design` writes the
tokens, palette and component specs from this direction.

**Pipeline:** Illustrator/Figma vector sources → raster at 2× (2048 atlas cap) → TexturePacker atlases per
scene → Spine 4.2 rigs for characters and UI motion → Unity Addressables groups per kingdom → URP 2D
lights and a small set of custom shaders for gem glow and tile reveals. Every asset ships with its source
file (`.ai`/`.psd`/`.spine`) in Artifactory or Git LFS, never only the PNG.

**Quality gate (measured, not vibes):**

| gate | target |
| --- | --- |
| frame rate | 60 fps on a 2021 mid-range Android (e.g. Redmi Note 10), 9×9 board + FX |
| allocations | 0 B/frame in the board loop (GC spikes are what make match-3 feel cheap) |
| draw calls | ≤150 on the board screen; one atlas per screen |
| install | base ≤150 MB, first kingdom streamed, cold start ≤3 s |
| UI text | WCAG AA (4.5:1) on every button and goal chip — checked with `replica-design/contrast.py` |
| animation | power-up creation/spawn ≥8 frames at 12 fps, obstacle break 3 damage stages + break, no linear tweens |
| RTL | every screen mirrored and reviewed in Persian before it is called done |

**Asset budget for one kingdom (the slice needs one):** ~5 gem types × (idle, selected, shine,
pop) ≈ 20; 8 obstacle types × (3 damage stages + break) ≈ 32; 4 power-ups + Super ≈ 25 frames;
5 in-game boosters + 3 pre-level ≈ 16 icons/VFX; ~60 UI elements and chips; 1 painted kingdom
background (2×) + ~40 building sprites, ~12 with build animation; 4 rigged characters × 3–5
expressions and portraits; 1 storyboarded 90-second episode. **≈ 350–450 polished assets.** At
professional quality that is roughly **2 senior 2D artists + 1 UI artist + 1 Spine animator for
~3 months**, plus an art director part-time, plus audio (1 composer loop + ~25 SFX). Anything less
shows up immediately next to the original — and the entrepreneur pass will not save a game whose
first frame looks indie.

## Build order

1. **M0 — feel prototype (no art, no server), ~2 weeks.** `Shazdeh.Core` board engine + a grey-box
   Unity scene: swap, cascade, gravity, the four power-ups and their combos, goal tracking, move
   counter, win/lose, 10 hand-authored levels, local save. Screens S05, S06, S08, S09 (ugly). Tables:
   none. Routes: none. Exit test: 60 fps in the editor, engine unit tests green, and 5 people who
   play match-3 say it feels right.
2. **M1 — must-haves, server-backed, ~4 weeks.** Auth (1–5), wallet, lives, attempts and extra moves
   (10–16), districts/tasks/chest (19–23), settings, world map. Screens S01–S11, S14–S17, S27, S28.
   Tables: `players` … `chest_grants` (20 of 29). Routes: 1–16, 19–25, 29–30. Exit test: a new device
   restores progress; killing the app mid-attempt loses nothing; a replayed webhook grants nothing.
3. **M2 — should-haves, ~4 weeks.** Boss boards and stages (S12, S13), boosters (S05/S06), magic pots,
   episodes, hard/super-hard cadence, level chests and streaks, IAP (26–28, 33). Tables: all 29.
   Routes: all 33. Exit test: purchase, refund and restore all reconcile with the ledger.
4. **M3 — could-haves + entrepreneur fixes.** Profile, stats, episode replay, notifications, then
   whatever `/replica-entrepreneur` ranks from real reviews (top complaint themes become features).
5. **M4 — brand, launch, deploy.** `/replica-brand` (name/trademark/domain, sweep must be clean),
   `/replica-launch` (listing), `/replica-deploy` (preflight + store submission).

## What this environment cannot do (so nobody is surprised later)

- No Unity, no .NET SDK here: `Shazdeh.Core` is authored and unit-tested in the repo, but compiling
  and running it needs Unity 6 or the .NET SDK on your machine, plus GitHub Actions (GameCI) or Unity
  Cloud Build for CI. The API and `schema.sql` *can* be run here (the schema already was).
- No art team here. This turn produces direction, tokens and specs; the 350–450 assets need humans.
- No store accounts, no RevenueCat keys, no domains. Those are yours to create; the docs list exactly
  which keys go where.

## Summary

Stack in one line: **Unity 6 + C# deterministic board core, one Fastify/TypeScript API over Postgres,
RevenueCat for money, R2 for art, Fly for hosting.**
Tables 29 (+2 views), routes 33, enums 10. Riskiest parts: the board engine's determinism, the
server-authoritative wallet under retries/races, and the art budget that "source-level graphics"
actually implies. Next step: **`/replica-design`** — palette, type, spacing, component specs and the
Persian-royal art direction, with the RTL layout system that every screen will use.
