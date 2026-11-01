# Recon map: Royal Kingdom (Android / iOS)

Scope: **the single-player core loop** — kingdom home → match-3 level (goals, moves,
power-ups, boosters) → win/lose → potions & coins → district tasks → district chest →
next district. Plus lives, save/restore and settings. Social, PvP, collection and
live-ops events are mapped but marked out of scope for v1.
For: our own product (working name Ideal). Not affiliated with Dream Games.
Date: 2026-11-01
Sources: public only — help center, Play Store listing, public guides. No account was
used, no binary or asset was touched, no network calls were logged.
Original: Dream Games, Ltd. — https://play.google.com/store/apps/details?id=com.dreamgames.royalkingdom
4.8★ / 2.78M reviews / 100M+ installs / #3 top-grossing Puzzle / updated 2026-10-16.

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | Play Store listing | https://play.google.com/store/apps/details?id=com.dreamgames.royalkingdom | pitch, 5 screenshots, tags, IAP flag, live events strip |
| 2 | Help center, Gameplay Guide | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/section/36-gameplay-guide/ | the most complete feature list available publicly |
| 3 | Basics | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/faq/305-royal-kingdom-basics/ | core loop in their words, currencies, goals |
| 4 | Tasks and Districts | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/faq/617-tasks-and-districts/ | meta layer: tasks, districts, chest, "Do it" |
| 5 | World Map | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/faq/619-world-map/ | kingdoms, episodes, visiting old kingdoms |
| 6 | Kingdom Level / Dark Kingdom Level | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/faq/306-kingdom-level/ · /faq/455-dark-kingdom-level/ | inverted-gravity boss boards, item health, stages |
| 7 | Power-Ups / Combinations / Boosters | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/faq/177-power-ups/ · /faq/178/ · /faq/179-boosters/ | the full power-up & booster set |
| 8 | Lives / Coins / Potions | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/faq/176-lives/ · /faq/309/ · /faq/308/ | economy gates: 5 lives, 30-min refill, currencies |
| 9 | Events list (21 events) | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/section/46-events/ | live-ops surface area — out of scope v1 |
| 10 | Teams / Friends / Collection / Leaderboard | https://dreamgames.helpshift.com/hc/en/6-royal-kingdom-1676903479/ | social surface — out of scope v1 |
| 11 | Public guides & reviews | https://gamingonphone.com/guides/royal-kingdom-beginners-guide-and-tips/ · https://medium.com/@chrisjameswallace/royal-kingdom-the-next-puzzle-hit-from-dream-games-c7395e26b185 | difficulty cadence (hard every 10 levels), FTUE differences, board feel |
| 12 | Screenshots | in `replica/screens/` (to be captured) | see `replica/screens/README.md`; reference only, never shipped |

## Core loop

Swap gems to clear a board's goals within a fixed number of moves; each win pays
potions, and potions are the only way to finish district tasks that build the kingdom
and unlock the next district, kingdom and level batch.

Second loop (the one that monetises): fail a level → lose a life → 5 lives, one every
30 minutes → pay coins for extra moves, boosters or lives → coins come from levels and
events → event participation is gated by level number.

## Screens

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Boot & asset load | launch | splash, download/verify, "tap to start" | logo, progress bar | first install, update, offline |
| S02 | Sign-in / account | first launch, or S20 | guest, Google, Facebook; restore progress | provider buttons, "play as guest", skip | signed in, guest, error |
| S03 | FTUE tutorial board | first launch after S02 | teach swap, goals, first win | coach hand, dimmed board, forced move | scripted only |
| S04 | Home — kingdom | after boot | hub: play, currencies, tasks, world, shop, social | HUD pills (lives/coins/potions), Play button, Tasks icon, World icon, Shop, Settings, event tabs | new player, mid-district, district complete, event live |
| S05 | Pre-level card | Play on S04, or level node | show level number, difficulty, goals preview, pre-level boosters | difficulty badge (Normal/Hard/Super Hard), goal chips, booster toggles, Play button | fresh, boosters owned, no lives |
| S06 | Match-3 board | Play on S05 | the game: swap, match, power-ups, goals | board grid, move counter, goal tracker, in-game booster bar, pause, combo FX | normal, hard, super hard, low moves, no moves |
| S07 | Pause / quit | pause on S06 | resume, restart, settings, quit | modal, buttons | mid-level |
| S08 | Level won | goals met on S06 | reward sequence, streak/chest, continue | reward tally (potions/coins/boosters), collect-all, continue | first clear, replay, chest level |
| S09 | Out of moves | moves = 0, goals unmet | offer +5 moves for coins, retry, quit | modal, price, countdown, retry/quit | can afford, cannot afford |
| S10 | Level failed | loss confirmed | lose a life, retry | lives indicator, retry, quit | last life, lives available |
| S11 | Out of lives | Play with 0 lives | wait timer, ask team, buy with coins | countdown chip, coin price, team request | timer running, full |
| S12 | Kingdom level board | story node, from S04/S06 | attack castle/towers, multi-stage fields | item health bars, stage counter (x/y), inflated board physics | stage 1..n, boss |
| S13 | Dark Kingdom board | story node | same with Dark King's buildings | as S12 + dark palette | stage 1..n |
| S14 | Tasks & districts | Tasks icon on S04 | list districts/tasks, spend potions, progress | district header, task rows with potion cost, "Do it", progress bar | affordable, not affordable, all done |
| S15 | Build / task complete | tap task on S14 | construction animation, kingdom visibly changes | build VFX, before/after asset, continue | single task, whole district via "Do it" |
| S16 | District chest | all tasks done | open chest → coins, boosters, cards | chest card, reward reveal, claim | opened, pending |
| S17 | World Map | World icon on S04 | kingdoms timeline, visit old kingdoms, episodes | globe/route, kingdom cards, visit, episode button | current, completed, locked |
| S18 | Episodes | World Map, kingdom unlock | 1–2 min story scenes | video/scene player, skip, replay | first play, rewatch |
| S19 | Shop | S04 shop icon | coin packs, bundles, Kingdom Pass | product tiles, price, best-value tag, IAP sheet | default, purchased, store error |
| S20 | Settings | gear on S04 | sound, music, haptics, notifications, help, terms, account, delete | toggles, links, confirm dialogs | toggles on/off, delete flow |
| S21 | Profile | avatar on S04 | username, avatar, stats, progress | avatar picker, stats list, edit name | name change cooldown |
| S22 | Leaderboard | S04 | top 1000 world/country, weekly contest, friends | tabs, rows with rank/avatar/score | loading, loaded |
| S23 | Teams | S04 | browse/join/create, team chat, team events | search, team card, join/leave, chat | member, not member, full |
| S24 | Friends | S04 | add/invite, partner events, life gifts | search, invite link, friend rows | empty, filled |
| S25 | Collection | S04 | card sets, packs, set completion rewards | set grid, card detail, pack open | incomplete, complete |
| S26 | Event screens (21) | event tab on S04 | each event = stages/rounds + leaderboard + rewards | event HUD, stage map, round result, rank | locked by level, live, ended |
| S27 | Magic Pots | in-level, level 32+ | power-ups earned at level start | pot tiers, reward reveal | locked, tier 1–2 |
| S28 | Generic modals | anywhere | confirm, connection lost, maintenance, "new levels" | dialog, toast, banner | offline, maintenance |

Screens for the v1 slice: S01–S11, S14–S17, S27, S28 plus S12/S13 as one boss-board
variant. S18–S26 are mapped but out of scope (see below).

## Flows

```
F01 First run to first district
    S01 -> S02 -> S03 -> S04 -> S05 -> S06 -> S08 -> S04 -> S14 -> S15
    happy path taps: 11 (plus ~8 swaps in the tutorial)
    edge: user skips sign-in, closes app mid-tutorial, reinstalls (guest progress lost)
```
```
F02 Play a level and bank the potions
    S04 -> S05 -> S06 -> S08 -> S04
    happy path taps: 5 (play, play, swaps, collect, continue)
    edge: out of moves mid-board, app backgrounded, no lives, replaying a cleared level
```
```
F03 Fail, buy moves, or lose a life
    S06 -> S09 -> S06 (buy) | S06 -> S10 -> S05 (retry) | S06 -> S10 -> S11 (no lives)
    edge: exactly enough coins, coin price rises with each purchase in a level,
          "quit" after paying, buying on the last move
```
```
F04 Wait for lives
    S04 -> S11 -> countdown -> S04
    edge: refill while app closed, asking a team for lives, Kingdom Pass raising the cap
```
```
F05 Build a district
    S04 -> S14 -> S15 -> S14 -> S16 -> S04 -> S17
    happy path taps: 6
    edge: not enough potions, "Do it" for the whole district, chest left unopened while
          a new district unlocks, revisiting a completed district
```
```
F06 Boss board
    S04 -> S05 -> S12/S13 -> stage clear -> next stage -> S08
    edge: power-ups-only items, multi-stage move carry-over, boss AoE
```
```
F07 Explore
    S04 -> S17 -> kingdom card -> Visit -> S04 | S17 -> S18 -> S04
    edge: locked kingdom, episode not downloaded, offline
```
```
F08 Economy spend
    S04 -> S19 -> IAP sheet -> delivery -> S04
    edge: purchase cancelled, purchase pending, restore on new device, price mismatch
```
```
F09 In-level boosters
    S05 (pre-level toggle) -> S06 -> in-game booster -> S06
    edge: zero boosters owned, booster on an empty area, undo after booster
```
```
F10 Save and restore
    S02 -> Google/Facebook -> progress restored
    edge: conflict between two saves, account deletion, sign-out
```
Out of scope v1 (mapped only): teams, friends, life gifting, leaderboards, all 21
events, PvP arenas, collection/cards, Kingdom Pass, monthly seasons.

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Button | primary (green/gold), secondary, ghost, danger, icon-only | default, pressed, disabled, loading | all |
| HUD currency pill | lives (with timer), coins, potions | normal, low, full, "+" affordance | S04, S05, all modals |
| Timer chip | mm:ss countdown, "full" | ticking, paused, expired | S10, S11 |
| Goal chip | clear item X, collect Y, break layer Z | progress 0/3, complete | S05, S06, S12 |
| Move counter | normal, ≤5 left, 0 | warn state pulses at ≤5 | S06 |
| Board cell | match item (5 types), power-up, obstacle layer, blocker | idle, selected, hint, exploding, falling | S06, S12, S13 |
| Power-up glyph | rocket H/V, spinner, dynamite, electro ball, super electro ball | created, armed, triggered | S06 |
| Booster tile | hammer, battle ram, drill, wizard hat, bomber plane; pre-level rocket/dynamite/electro | owned count, empty, selected | S05, S06 |
| Item health bar | castle, tower, wall, shield, golem, firework tower | full, damaged, destroyed | S12, S13 |
| Reward burst | potion, coin, booster, card | single, batch, collect-all | S08, S16 |
| Modal | info, confirm, reward, purchase, error | open, closing | everywhere |
| Task row | build task with potion cost | affordable, locked, done | S14 |
| Progress bar | district, kingdom, event stage, pass | determinate, complete | S14, S17, S26 |
| Chest card | district chest, level chest, event chest | closed, opening, opened | S16, S08 |
| Kingdom card | current, completed, locked | with episode badge | S17 |
| Tab bar / icon rail | home, tasks, world, shop, social, events | active, badge (new/claimable) | S04 |
| List row | leaderboard, team, friend, collection, settings | default, highlighted, disabled | S21–S25 |
| Toast / banner | reward, error, live-ops banner, "new levels" | auto-dismiss | global |
| Cutscene player | episode, story beat | playing, skippable, buffering | S18 |

## Inferred data model

```
Player         id, display_name, avatar_id, kingdom_progress, level_number,
               coins, potions, lives(count, next_refill_at), created_at,
               auth_provider (guest|google|facebook), settings(json)
               evidence: S02 S04 S10 S11 S20 S21 · help "Saving Game Progress", "Lives"
               confidence: high

Level          id, number, type (normal|hard|super_hard|kingdom|dark_kingdom),
               board_layout_id, move_limit, goals[], reward_potions, reward_coins,
               unlock_after_level, episode_id
               evidence: S05 S06 S08 S12 · help "Kingdom Level", "Challenging Levels"
               confidence: high

Attempt        id, player_id, level_id, started_at, ended_at, result
               (win|lose|quit), moves_used, boosters_used[], extra_moves_bought,
               potions_earned
               evidence: S09 S10 · economy needs it; server-side cost model
               confidence: medium

BoardCell      row, col, item_type (5 match items), power_up, layers[], blocker,
               health (boss boards only)
               evidence: S06 S12 · help "Match Items", "Kingdom Level Items"
               confidence: high (runtime state, not persisted)

PowerUp        kind (rocket_h, rocket_v, spinner, dynamite, electro_ball,
               super_electro_ball), created_by_pattern (4-line, 4-square, L/T, 5-line),
               combo_with
               evidence: help "Power-Ups", "Power-Up Combinations"
               confidence: high

Item           id, kind (box, snow, ivy, potion_tube, steam_bomb, flower_pot, ...),
               layers, hits_to_clear, needs_power_up
               evidence: help Items section (dozens of articles)
               confidence: high (list incomplete — only first three are public per page)

KingdomItem    id, kind (castle, tower, wall, shield, giant_golem, firework_tower),
               health, destroyed_by (match|power_up)
               evidence: help "Castle + Tower + Wall + Shield", "Giant Golem"
               confidence: high

Kingdom        id, name, order, district_ids[], episode_id, unlocked_by
               evidence: S17 · help "World Map"
               confidence: high

District       id, kingdom_id, order, task_ids[], chest_id, state
               (locked|active|complete)
               evidence: S14 S16 · help "Tasks and Districts"
               confidence: high

Task           id, district_id, order, potion_cost, build_asset_id, label
               evidence: S14 S15 · confidence: high

Chest          id, source (district|level|event), contents{coins, potions, boosters,
               cards}, claim_state
               evidence: S16 · confidence: high

Episode        id, kingdom_id, media_ref, unlocked, watched
               evidence: S18 · help "Episodes" · confidence: high

BoosterInventory  player_id, booster_kind, count
               evidence: S05 S06 · confidence: high

MagicPot       tier, threshold, rewards[]
               evidence: S27 · help "Magic Pots" · confidence: high

Product        sku, kind (coin_pack|bundle|pass), price, contents, badge
Transaction    id, player_id, sku, receipt, state (pending|granted|refunded)
               evidence: S19 · confidence: high (server-side verification is ours)

LevelUnlockCadence   batch, released_at   (new levels every two weeks)
               evidence: help "New Levels" · confidence: medium

Team           id, name, badge, member_ids[], join_policy, chat_channel
TeamMember     team_id, player_id, role, last_active
LifeRequest    id, requester_id, team_id, granted_by[]
Friend         player_a, player_b, gifted_at
Event          id, kind, min_level, schedule, stages[], reward_ladder, leaderboard_id
EventEntry     event_id, player_id, stage, score, rank
CollectionCard id, set_id, rarity, art_ref
CardSet        id, card_ids[], reward
LeaderboardEntry  board_id, scope (world|country|team|friends), rank, player_id, score
               evidence: S22–S26 · confidence: high · all out of scope for v1
```

Relationships: Player 1-n Attempt; Player 1-1 KingdomProgress → Kingdom 1-n District
1-n Task; District 1-1 Chest; Level n-1 Kingdom; Player 1-n BoosterInventory;
Player 1-n Transaction; Team 1-n TeamMember; Event 1-n EventEntry.

## Feature matrix

See `features.csv` (47 rows). Must: 22, should: 13, could: 5, skip: 7.
Parity at day 0: `parity.py` reports 0.0 / 100, not shippable, 0 of 22 must-haves.

## Out of scope (cannot or should not be cloned)

- **Art, characters, audio, animation.** King Richard, Princess Bella, the Wizard, the
  Dark King, the kingdom art, gem art, sounds and the logo are Dream Games' IP and are
  not part of "the feature". We design our own cast and art direction in
  `/replica-design` and `/replica-brand`.
- **The level catalogue.** Thousands of hand-tuned boards, tuned over years of
  A/B-tested difficulty. We build our own level format and author a starter set.
- **Live-ops calendar and the 21 events**, seasons, Kingdom Pass, PvP arenas,
  leaderboards. These need a service, a population and an economy team; they are the
  reason the original earns, not the reason it is fun.
- **The player network** — teams, friends, life gifting, chat — and its data.
- **Exact economy numbers** (potions per level, coin prices per extra move, event
  ladders). Public sources do not publish them; copying them would also be copying
  their tuning. We set our own and tune with `replica-diff` + playtests.
- **Their ad attribution / analytics / anti-cheat stack.**
- **The Royal Match universe tie-in.**

## Hard parts

1. **The board engine**, not the screens: cascades, gravity, dead-board detection and
   reshuffle, power-up creation and combination matrix, obstacle layering, boss boards
   with inverted gravity and item health. This is a real engine, in a fixed-step loop,
   and it is where most of the bugs will be.
2. **Difficulty tuning.** The original ships a Hard every 10 levels and a Super Hard
   after it, plus an easy "blasty" level after each Super Hard. Without live telemetry,
   our curve will be guesswork until we have players.
3. **Economy and lives**, server-authoritative (otherwise one modified client kills the
   game): lives refill, coin sinks, potion faucets, idempotent IAP grants.
4. Art production volume: a match-3 needs a lot of polished assets per obstacle and
   per district — that is a budget line, not an engineering line.

## Size

Screens 28 (17 in the v1 slice), flows 10 (6 in the slice), entities 21.
Hard parts: board engine, difficulty tuning, server-authoritative economy, art volume.
Size: **XL as a full product, L (a quarter) for the slice in this map, M (a few weeks)
for a vertical slice** — one kingdom, 20 levels, one district chain, no IAP. Any claim
of a weekend match-3 is a claim about a prototype, not this game.
