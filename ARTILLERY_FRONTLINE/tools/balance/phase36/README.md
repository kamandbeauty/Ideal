# Phase 3.6 balance tools

These scripts are **models**, not game measurements. They reproduce the damage rules in the Godot
source (`scripts/coastal/`) in Python so that weapon, aircraft, combined-attack and support
options can be ranked before a change is made. The headless tests in `tests/` and the device
tests are what verify the game itself.

Requirements: Python 3 with numpy. The repository does not vendor numpy. Install it outside
the repository, for example:

    pip install --target /home/user/pylibs numpy
    export PYTHONPATH=/home/user/pylibs

Run every script from this directory (`tools/balance/phase36`). Some runs take minutes; run
them in the background if the shell has a time limit.

## Files

| File | What it does | Output |
|---|---|---|
| `combat_sim.py` | Monte Carlo of the damage rules: weapon spread, bullet drop for blast shells, segment-to-sphere hit test, `DamageModel` armour, critical ×1.6, headshot ×2.2 for infantry, splash on ground and craft, aircraft orbit and the optional aircraft lead. Library module, no output. | — |
| `phase36_matrix.py` | Direct, splash and realistic scenarios (aim 0.0, 0.3, 1.0 degrees), with and without aircraft lead, plus an aircraft orbit-speed sweep. | `phase36_matrix.txt` |
| `realistic_aim_sweep.py` | Realistic scenario at aim error 0.5, 1.5 and 3.0 degrees, n=200, aircraft lead on. | `realistic_aim_sweep.txt` |
| `combined_attacks.py` | Combined-attack model: all enemies in position at t=0, greedy kill order, 1.0 s switch delay, no support, 6000 HP emplacement. Hit probability is an assumed bound (0.3 and 1.0). | `combined_attacks.txt` |
| `campaign_support_model.py` | Campaign model with one HP timeline. Repair and Airdrop are used after the player notices HP at or below a threshold T and reacts after `react` seconds. Craft launch gap 0 s and 6 s. Built on `../prototype_campaign_model.py`. | `campaign_support.txt` |

## How to read the outputs

- Time-to-kill (TTK) includes bullet flight time. "no kill" means no kill within the sample's
  time limit. "hit" is the hit rate of the sample.
- Realistic runs use a Gaussian aim error in degrees; the value in the header is its size.
- Campaign output reports the lowest HP reached during the mission, not the HP at the end.

## What the models assume

- Targets are spheres. There is no cover, no terrain blocking and no ground motion in the
  approach phase of landing craft.
- The player's reaction time, in the campaign model, is the only timing error.
- Hit ratios of infantry against the emplacement and the per-profile damage rates in
  `../prototype_campaign_model.py` are **assumed**. The campaign output ranks options; the
  absolute HP numbers are not measured.
- Ammunition reserve is 999 (the game's value), so reserve shortage is not modelled.

## Limitations

- These scripts do not run the game. Device play and the Godot test suite are still needed
  for the final balance decision.
- No output here is a measured result for the emplacement or for real players.
