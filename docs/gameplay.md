# Gameplay — one turn, and what the player sees while it happens

This is the loop the code actually runs (M4). It exists because "match-3 feels good" is not a
specification: a turn is a fixed sequence of phases, each with a duration, and the view is only
allowed to read the model's event list. Nothing in this document changes the rules layer — the rules
are `LevelRun`, `MoveResolver` and `Goals`, and they are deterministic and seeded.

## 1. The turn

```
press ──► release ──► TrySwap ──► (accepted?) ──► swap ──► clear ──► settle ──► next move
                          └────► (rejected) ──► push-back ──► next move
```

| phase | what moves | duration | where |
| --- | --- | --- | --- |
| swap | the two tiles trade cells | 120 ms | `BoardScreen.PlaySwap` |
| clear | every `PieceClearedEvent` cell rises 0.14 of a cell, shrinks to 8 %, and leaves an `fx_spark` that grows, turns 45° and fades | 140 ms + a 340 ms spark | `PlayClear`, `SpawnSpark` |
| settle | every cell above a cleared cell falls back into place, staggered by row distance | 190 ms + 12 ms per row | `PlaySettle` |
| push-back | a rejected pair leans 0.16 of a cell toward each other and springs back | 160 ms | `PlayRejected` |

The durations live as `const` fields at the top of `BoardScreen`, so "the game feels slow" is a
one-line change. Easing is `EaseOutCubic` for movement; the stars on the result card use
`EaseOutBack`, one 220 ms pop each, staggered 100 ms apart.

Two rules that keep this honest:

1. **The view never decides.** `Play()` calls `_run.TrySwap` and then *reads* `MoveResult.Events`. It
   never inspects the board to guess what changed, and a phase never mutates board state. If the
   animation and the model ever disagree, the model wins by construction — the screen redraws from
   `_run.Board` at the end of every phase.
2. **Input is blocked while a phase runs.** `Update` returns early while `_tweens` is non-empty, so a
   fast player cannot start a second swap inside a cascade. The model would reject it anyway; this
   just stops the view from looking broken.

When `_run.Status` leaves `Playing`, the result overlay is *deferred* until the last cascade has
finished (`SettleTurn` → `AfterMove`), because a modal on top of a half-played cascade reads as a bug.

### What clears, and what does not

A move is accepted only when it builds a **line of three or more** of one colour — a row, a column, or
the crossing of the two. That is the whole rule; `MatchFinder.find_runs` is the only thing the resolver
asks when it decides what to take.

A **2 x 2 block is not a match.** The Unity prototype treated one as a match and swept every square on
the board whenever a move resolved, and because a dealt board is settled of lines but not of squares,
five-colour levels opened with a block about thirty per cent of the time: the player matched three
fruit and four unrelated pieces elsewhere burst with them. The rule is gone (`move_resolver.gd`,
`_resolve_cascades`), the shape survives in `MatchFinder.find_squares` only so the tests can prove those
blocks are still standing after a move, and a swap that builds nothing but a square is rejected as
"no match" (`TEST STAGE 5B`).

## 2. Input

Both gestures exist, deliberately:

- **Swipe.** Press, drag at least 0.45 of a cell, release. The dominant axis decides the direction, and
  a drag that leaves the board is ignored rather than clamped.
- **Tap, then tap.** Tap a piece to select it, tap a neighbour to swap, tap the same piece to deselect.
  This is the accessible path: it works with a switch device, a screen reader cursor, and a thumb that
  cannot swipe reliably. Both gestures call the same `Play()`.

A tap on a non-neighbour moves the selection instead of clearing it, so a mis-tap costs nothing.

## 3. The HUD

- **Moves**, in a pill at the top left: `حرکت ۱۲`, decremented by the model, never by the view.
- **Goals**, one chip per goal (up to three), right to left: the goal's own icon (`piece_*` or
  `obstacle_*`), then `۴ از ۱۲`. A finished goal turns gold and stays gold. The chips are created at
  full width once and hidden when a level has fewer goals, so the layout does not jump between levels.
- **Hint line**, one line under the chips, empty during play. It carries a level's configuration
  error, the «یک خانه را انتخاب کن» prompt while a booster is armed, and it is where a rejected move
  will say why once we write copy for it.
- **Boosters**, five chips along the bottom edge (`booster_*` at 40 dp), each with its count in the
  corner; the whole bar is dimmed when the level is over or the count is zero. See §5.

## 4. Stars

Stars are **derived, not stored** (`Core/StarRating.cs`):

| stars | condition |
| --- | --- |
| 1 | the level was cleared, however few moves were left |
| 2 | cleared with ≥ 25 % of the move budget unspent (rounded up) |
| 3 | cleared with ≥ 50 % of the budget unspent (rounded up) |

A record keeps `bestMovesLeft`, so `LevelRecord.Stars(level.MoveLimit)` reports the best a player has
ever done without a save migration — and the server can recompute a client's claim from the replay it
already validates. Thresholds are integer arithmetic: a 10-move level pays its second star at 3 left
and its third at 5.

The result card shows three `icon_star` sprites: earned ones in gold, the rest as muted outlines. When
the clear was not perfect, the body names the number still needed for the next star, which is the only
place in the game where the player is told the rule.

## 5. Boosters

Five boosters, one chip each, along the bottom of the board (`Core/Boosters.cs` for the rules,
`BoardScreen.BuildBoosterBar` for the bar). They cost **no move** — that is what makes them boosters
rather than power-ups — and they do not add to `MovesUsed`, so a level cleared with four hammers still
reports the moves it actually spent.

| booster | effect | coins |
| --- | --- | --- |
| پتک (mallet) | removes one cell | 40 |
| قوچ (ram) | a whole row | 60 |
| مته (auger) | a whole column | 60 |
| گردباد (whirlwind) | reshuffles the board, no clears | 80 |
| شاهین (falcon) | three small blasts | 100 |

The flow is **arm, then aim**: tapping a chip lights it gold and the hint line says «یک خانه را انتخاب
کن»، the next tap on a cell fires it there, and a second tap on the same chip disarms. While a booster is
armed a drag is not a swipe — the one thing a nervous player must not be able to do is spend a booster on
a swap they meant to make.

Two rules keep the counts honest:

- **A refused target costs nothing.** `GameSession.TryUseBooster` consumes from the bag, calls the board,
  and puts the booster back if the board says no; the screen never sees the intermediate state.
- **Counts are capped at 9 and floored at 0**, and a purchase charges for exactly the number that fit
  under the cap — buying three at 8 owned costs one booster's worth of coins, not three.

The prices are tuned to *this* game's rewards (a first clear pays 10 coins), not copied from the
original: at the original's prices nothing would be affordable for the first fifty levels. A fresh save,
and any save migrated from v1, starts with one of each so the mechanic can be felt before it is bought.

## 6. What M4 does not do yet

- **No board reshape on a goal** — the level's goals are fixed at start, as the rules layer defines.
- **No booster shop in the level.** `ShopScreen` replaces spent boosters from the home screen; there is
  still no way to buy one *during* a level, which is where the original puts its "you are out of mallets"
  offer.
- **No pre-level booster placement** — a booster is fired mid-level only, never set on the board before
  the first move.
- **No magic pots** (power-ups granted at the start of a level).
- **No power-up tap-to-fire.** Power-ups are created and triggered by swaps only (`MoveResolver`).
- **No sound, no haptics on a match**, though `SaveData.sfxOn`/`hapticsOn` already gate them.
- **Particles are one sprite per clear** (`fx_spark`), capped at 40 alive. There is no pool and no
  `ParticleSystem`: a cascade of 20 clears allocates 20 short-lived GameObjects, which the profiler
  will eventually ask us to fix, and not before.
- **No cascade-stagger pacing beyond settle**: each cascade step reuses one clear+settle pair rather
  than a longer choreography, because the event list gives positions, not distances fallen.
- **No "level complete" chest reveal**: the chest sprite is drawn but the reward is still text.
