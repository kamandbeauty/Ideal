class_name DamageModel
extends RefCounted
## Damage rules for enemy units: formal armour and damage resistance, and the critical-hit roll.
## Pure functions, so the rules are testable without a scene. Headshots stay in EnemySoldier
## (HEADSHOT_MULTIPLIER); a critical hit multiplies on top of a headshot.

## Damage multiplier for a critical hit. Tune here; the readout and feedback read the same value.
const CRITICAL_MULTIPLIER: float = 1.6
## Chance per hit that a critical lands, by unit kind. Landing craft and barrels have no critical spot.
const CRITICAL_CHANCE: Dictionary = {"soldier": 0.12, "vehicle": 0.08}
## Upper bound on resistance, so no armour can make a unit invulnerable.
const MAX_RESISTANCE: float = 0.9

## Resistance a full-plate unit (armor 1.0) gives against a hit of this size. Equal to the earlier
## armour multipliers 0.22 / 0.65 / 0.90 for hits up to 25, below 100 and above that.
static func hit_resistance(amount: float) -> float:
	if amount <= 25.0:
		return 0.78
	if amount < 100.0:
		return 0.35
	return 0.1

## Fraction of incoming damage removed by a unit with this armour rating (0 = none, 1 = full plate).
static func damage_resistance(amount: float, armor: float) -> float:
	return clampf(clampf(armor, 0.0, 1.0) * hit_resistance(amount), 0.0, MAX_RESISTANCE)

## Health actually removed from a hit of `amount` by a unit with this armour rating.
static func taken(amount: float, armor: float) -> float:
	return amount * (1.0 - damage_resistance(amount, armor))

## Multiplier applied to a hit: critical hits use CRITICAL_MULTIPLIER, others use 1.
static func critical_scale(critical: bool) -> float:
	return CRITICAL_MULTIPLIER if critical else 1.0

## True when a uniform roll in [0, 1) lands a critical for this kind of unit.
static func is_critical(kind: String, roll: float) -> bool:
	return roll < float(CRITICAL_CHANCE.get(kind, 0.0))
