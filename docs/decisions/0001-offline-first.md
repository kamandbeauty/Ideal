# ADR 0001 — Offline first: what needs a server and what does not

Status: accepted 2026-11-01. Answers the question "does the game need a server, is it offline?" and
locks the M1 scope.

## Short answer

**The game plays offline.** The core loop — levels, potions, tasks, districts, chests, lives — needs no
network. A player on a plane gets the whole loop.

**Three things need a network, and only one of them is non-negotiable:**

| need | off-line consequence | verdict |
| --- | --- | --- |
| In-app purchase receipts | the store will not accept a purchase without a network anyway; *validating* the receipt is the part that must not be done by the client | **server required — when we ship IAP.** Until then: no server needed at all |
| Cloud save / cross-device | losing progress on a reinstall is the #1 review complaint in this genre | optional, high value |
| Live-ops, leaderboards, teams, PvP, anti-cheat | we deliberately left all of these out of the slice (`features.csv` → skip) | not needed |

Anti-cheat is only worth its cost when cheating buys something: a competitive leaderboard, a shared
economy, or paid currency. In a single-player offline game, a player editing their own save harms only
their own fun. That is a product decision, not a technical one, and it is reversible: seeds, hashes and
replays already exist in the engine (`LevelRun.StateHash`), so a server can be added later without
touching gameplay.

## What the original does (and what we actually know)

The Play Store listing tags Royal Kingdom **"Offline"**, and it does play without a connection for the
core loop. It also runs 21 time-limited events, teams, ladders and purchases, which cannot be offline.
We cannot see inside it (and will not: no decompiling, no private endpoints). Conclusion for us: an
offline core loop with an online-optional layer is exactly the shape to copy, not their implementation.

## Decision

1. **Local save is the source of truth while playing.** One JSON file in `Application.persistentDataPath`,
   written atomically with a `.bak` fallback and a schema version for migrations.
2. **The economy is rule-based and testable in the engine**, not in the UI: `Wallet`, `Lives`,
   `Progression` live in `Shazdeh.Core` with an injected clock, so all of it is unit tested with no
   Unity and no server.
3. **No accounts in M1.** No sign-in wall, no e-mail, no permissions. A local player id is generated
   on first launch.
4. **The server, when it arrives, has one job at first: validate purchases and (optionally) back up the
   save.** The schema in `replica/schema.sql` is the cloud mirror and stays as designed — it is not
   dead code, it is the thing that makes step 5 possible.
5. **Sync, when it arrives, is last-write-wins on a monotonic save version, with the server never
   granting currency the client did not earn.** Conflicts are resolved by keeping the higher
   `progressVersion` and logging the loser; a "progress on another device" dialog explains it.

## What changes in the architecture document

- `replica/architecture.md` keeps the API and schema, but M1 no longer depends on it: `POST /v1/attempts`,
  the wallet routes and auth are **deferred until IAP or cloud save is switched on**.
- The client gets a save layer (`Shazdeh.Game/SaveStore`, `Shazdeh.Content/SaveCodec`) and an economy
  layer (`Shazdeh.Core/{Wallet,Lives,Progression}`) that the server will later mirror, not replace.
- Anything a server would have decided (a win, a reward) is decided by the deterministic engine and
  written to the save; the replay hash is stored so a future server can audit it.

## Consequences

- Testability goes up: the entire economy runs in NUnit with a fake clock.
- Distribution gets easier: no backend to pay for, no uptime to keep, no GDPR data processor for
  gameplay data, and the store listing can say "offline" honestly.
- We must be careful about one thing: **once IAP exists, purchase grants cannot be client-side.** That
  is the line, and it is written down here so nobody crosses it by accident.
