# Component specs — کاخ شازده

Every component from `replica/recon.md` step 5, with the states the original showed plus the ones it
should have. Tokens are names from `tokens.json` — no raw hex in a component. Sizes in dp (Unity UI
units at 1× reference 1080×1920). Minimum touch target 48 dp everywhere. All layouts RTL-first.

Conventions used below: `tokens` = design tokens; `a11y` = semantics + keyboard/gamepad + screen reader;
`used on` = S-IDs from the recon map.

---

## Button

```
variants   primary (firouzeh enamel), secondary (ivory), gold (rewards), ghost, danger, icon-only
sizes      sm 40, md 48, lg 56; icon-only 48×48, 56×56
states     default, pressed (sink 2dp), focus (3dp accent ring, 4dp offset), disabled (40% alpha, no
           press), loading (label stays, spinner left of label in RTL), locked (padlock + level)
tokens     bg accent / on-accent · radius md · type button-label 17/800 · shadow panel
a11y       real button node with label; visible focus ring for gamepad; loading keeps the accessible
           name; disabled is announced, not just dimmed; min 48dp; haptics light on press
used on    all
```

## HUD currency pill

```
variants   lives (with refill ring), coins, potions
sizes      h 36, min-w 88; icon 24; amount 18/800
states     normal, low (amount < cost, muted → accent), full, refilling (ring animates, tap → S11),
           plus-affordance (tap opens the shop), offline (values from cache, muted with a dot)
tokens     surface-raised face, gold 1dp frame, text / text-muted, radius pill
a11y       label reads "سکه: ۱٬۲۴۰" not "1240"; ring has a text equivalent of the countdown
used on    S04, S05, S06, S08–S11, S14, S16, S19
```

## Timer chip

```
variants   countdown mm:ss, paused, full
sizes      h 28, text 14/700 tabular
states     running, paused (app backgrounded), expired (auto-hides and refills), >1h (shows h:mm)
tokens     surface, text-muted → text when < 5 min
a11y       announces remaining time on change, not every second
used on    S10, S11, S20
```

## Goal chip

```
variants   count-goal (clear N of an item), collect-goal, layer-goal, boss-goal (item health)
sizes      44 tall, icon 28, count 13/700
states     in-progress (0/N), progress, complete (gold tick, pop 200 ms), failed (dimmed on lose)
tokens     ivory tile face, border, text ink on tile (role: on-goal = on-gold family)
a11y       icon + count + item name as one label; completion announced; never colour-only — a tick
           and a strike-through both appear
used on    S05, S06, S12, S13
```

## Move counter

```
variants   normal, low (≤5), zero
sizes      counter 34/900, label 12/600
states     normal, warn (pulses 1 Hz, colour shifts to warning, haptic once), zero (board input
           disabled, S09 opens after the last cascade settles)
tokens     text, warning, danger
a11y       reads "حرکت باقیمانده: ۴"; warn state also changes the icon, not just the colour
used on    S06, S12, S13
```

## Board cell

```
variants   empty, match item (5 types × idle/selected/hint/pop), power-up, obstacle (layers), blocker,
           hidden (dark), boss-target
sizes      96×96 (2× = 192 source)
states     idle, pressed (sink 2%), selected, swapping (140 ms), falling, exploding, dead (dimmed during
           a fail sequence), hinted (pulse, 4 s cooldown)
tokens     no UI tokens — art per art-direction §3–4; selection ring uses accent 3dp
a11y       no per-cell focus for screen readers (a 9×9 grid is unusable that way); instead a "level
           summary" accessibility panel exposes goals and moves, and the game offers an assist mode
used on    S03, S06, S12, S13
```

## Power-up glyph

```
variants   arrow (H/V), spinner, bomb, shamse (electro), super shamse
sizes      same 96 cell, badge 28 in the corner
states     created (build-up 8f), idle (glow, 4f), armed, triggered (10f), combo-ready (both glow gold)
tokens     gold for the armed ring
a11y       state announced through the level summary; name in the goal chips when a goal needs one
used on    S06, S12, S13
```

## Booster tile

```
variants   Mallet, Ram, Auger, Whirlwind, Falcon; pre-level variants (arrow, bomb, shamse)
sizes      board bar 64×64, count badge 18; shop tile 84×84
states     owned (count), empty (dimmed, "get" badge), selected (gold ring + haptic), disabled in a
           level state that forbids it, purchased
tokens     surface-raised face, gold ring when selected, text-muted when empty
a11y       48dp min target, count read as a word, "buy" affordance is a separate button
used on    S05, S06, S17(shop), S14
```

## Item health bar

```
variants   castle, tower, wall, shield, golem, firework tower (boss boards)
sizes      w 64–160, h 8; segments 4
states     full, damaged (segments drop), critical (danger tint + shake), destroyed (debris, 300 ms)
tokens     success → warning → danger ramp, track surface
a11y       a numeric health is available in the level summary; segmented bar so it is not a gauge-only read
used on    S12, S13
```

## Reward burst

```
variants   single reward, batch (coins/potions/boosters), collect-all, level chest, district chest
sizes      icon 64, count 26/900, up to 4 rewards per row
states     queued, flying (600 ms), counted up (200 ms), collected (button disables, then Continue)
tokens     gold frame, on-gold text, pop motion
a11y       the whole burst is one announcement: "۳۵ پوشن، ۲۰ سکه"; Collect-all is reachable without
           waiting for the animation (skip on tap)
used on    S08, S16
```

## Modal

```
variants   info, confirm, reward, purchase, error/offline, maintenance, "new levels"
sizes      520 wide on phone, 4:3 max on tablet; padding 24; arch crown 3 steps
states     opening (280 ms arch wipe), open, closing, stacked (never more than 2), queued
tokens     scrim bg 72%, panel surface, radius panel, shadow pop
a11y       focus trapped, Escape/back closes, primary action is first in RTL reading order, no
           destructive default, text zoom-safe to 130%
used on    S07, S09, S10, S11, S20, S28
```

## Task row

```
variants   single task, "Do it" row (whole district), completed, locked (previous task not done)
sizes      72 tall, icon 44, cost chip 64×28, label 16/600
states     affordable, unaffordable (cost chip danger, button disabled + reason), completing
           (spend animation), done (checkmark, row collapses 200 ms later)
tokens     surface face, border, gold cost chip, success for done
a11y       row reads "ساختن حوض، ۲۵ پوشن"; button label includes the cost; disabled explains why
used on    S14
```

## Progress bar

```
variants   district, kingdom, event stage, chapter medal
sizes      h 8 (inline), 16 (hero); radius pill
states     determinate, near-complete (gold shimmer), complete (burst)
tokens     accent fill, surface-raised track, gold at complete
a11y       value announced as "۳ از ۷ تسک"; never the only indicator — a text count always exists
used on    S04, S14, S17, S26
```

## Chest card

```
variants   district chest, level chest, event chest, locked
sizes      240×280 card, 3 states of open animation (12f each)
states     closed (idle shimmer), opening (tap, 900 ms), opened (contents behind it), empty
tokens     gold frame, panel face, shadow pop
a11y       "جعبهٔ دیستریکت، باز نشده" + reveals are announced one by one with a skip
used on    S16, S08
```

## Kingdom card

```
variants   current, completed, locked, next
sizes      280×200, episode badge 32
states     idle, visited, unlocked (auto-camera pan), offline (no episode play)
tokens     surface, gold for completed medal, text-muted for locked
a11y       state in the label; locked card says the level needed
used on    S17
```

## Icon rail / nav

```
variants   home, tasks, world, shop, social, events (badges)
sizes      icon 28 in 56×56 targets, bottom safe area aware
states     active (accent + 3dp indicator), inactive (text-muted), badge (gold dot with count), locked
tokens     surface bar with 1dp border, accent indicator
a11y       each item is a labelled button in RTL order (home right-most), 48dp min, badge counted
used on    S04, S14, S17, S19, S22–S26
```

## List row

```
variants   leaderboard, team, friend, collection, settings toggle, settings link
sizes      h 64, avatar 40, trailing control 48
states     default, pressed, selected, disabled, offline (cached), empty list state
tokens     surface, border hairline, text / text-muted
a11y       row + trailing control are separate targets; toggles are switches with state, not checkmarks
used on    S20–S25
```

## Toast / banner

```
variants   reward received, error, live-ops banner, "new levels", offline
sizes      h 48, full width minus 32, top under safe area
states     entering (200 ms), visible 3 s (errors persist until dismissed), exiting
tokens     surface-raised, text, danger for errors
a11y       polite live region; never the only place a state change is reported
used on    global
```

## Cutscene player

```
variants   episode (90 s), story beat (5–10 s), first-run intro
sizes      full screen 16:9 letterboxed on portrait, skip 48dp top-start (i.e. top-right in RTL)
states     buffering, playing, paused, skipped, watched (replay available from S17)
tokens     scrim bg, text on video, accent progress line
a11y       subtitles on by default (Persian), audio description not needed for v1, skip is reachable
           from the first frame, respects reduce-motion by cutting camera moves
used on    S18
```

---

## RTL and localisation checklist (applies to every component)

- Mirror layout, not art: gems, characters and chests are never mirrored.
- Icons with direction (arrows, back) flip; icons of objects (hammer, coin) do not.
- Numbers: Persian digits, `٬` thousands separator, `٫` decimal; keep numerals LTR-embedded so
  "۱۲/۲۰" never reverses. Test every string with a mixed number + Latin token.
- No fixed-width labels derived from English strings; buttons size to content with 16 dp side padding.
- Truncation is banned on buttons and goal chips — the copy is shortened instead.
- Font weight: Vazirmatn 500/700/800 only; 900 for counters/display. No faux-bold.

## Where these get built

Unity UI (UGUI + TextMeshPro) in `Shazdeh.Meta` / `Shazdeh.Game`, driven by
`client/Assets/Core/Generated/Tokens.gen.cs` (generated from `tokens.json` by
`replica/design/gen_tokens.py`). Before any screen is built, M0 ships a `_DesignSystem` scene that
renders every variant and state above with grey-box art — that scene is the design-system check, and
it is rebuilt with real art at M2. No screen is allowed to invent a control that is not in this file.
