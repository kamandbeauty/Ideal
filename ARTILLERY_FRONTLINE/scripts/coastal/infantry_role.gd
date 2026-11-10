class_name InfantryRole
extends RefCounted
## Infantry roles. Each role has a different job on the battlefield, not just a different health pool:
## RIFLE advances, bounds and fires single rounds; HEAVY holds a firing line at range, sets up a
## bipod and fires short suppressive bursts; RPG keeps its distance, fires one anti-armour rocket
## from a clear line, then falls back to cover to reload.

enum Kind { RIFLE, HEAVY, RPG }

## Maps a wave cargo name ("soldier", "heavy", "rpg") to a role.
static func from_name(role_name: String) -> int:
	if role_name == "heavy":
		return Kind.HEAVY
	if role_name == "rpg":
		return Kind.RPG
	return Kind.RIFLE

static func name_of(kind: int) -> String:
	if kind == Kind.HEAVY:
		return "heavy"
	if kind == Kind.RPG:
		return "rpg"
	return "soldier"

static func max_health(kind: int) -> float:
	if kind == Kind.HEAVY:
		return 36.0
	return 20.0

## Formal armour rating for infantry: plate vests only for heavy infantry.
static func armor(kind: int) -> float:
	if kind == Kind.HEAVY:
		return 0.5
	return 0.0

## Walking speed relative to the wave's base infantry speed.
static func speed_factor(kind: int) -> float:
	if kind == Kind.HEAVY:
		return 0.7
	if kind == Kind.RPG:
		return 0.85
	return 1.0

## Distance from the emplacement at which the role stops and holds. Zero means it keeps advancing.
static func hold_distance(kind: int) -> float:
	if kind == Kind.HEAVY:
		return 22.0
	if kind == Kind.RPG:
		return 40.0
	return 0.0

static func holds(kind: int) -> bool:
	return hold_distance(kind) > 0.0

static func fire_range(kind: int) -> float:
	if kind == Kind.HEAVY:
		return 110.0
	if kind == Kind.RPG:
		return 120.0
	return 150.0

## Seconds a unit must keep a clear line before its first shot (bipod set-up, launcher aim).
static func setup_time(kind: int) -> float:
	if kind == Kind.HEAVY:
		return 1.1
	if kind == Kind.RPG:
		return 1.5
	return 0.0

## Rounds per volley.
static func burst_size(kind: int) -> int:
	if kind == Kind.HEAVY:
		return 3
	return 1

## Seconds between volleys for the roles that use a fixed interval (riflemen randomise theirs).
static func fire_interval(kind: int) -> float:
	if kind == Kind.HEAVY:
		return 4.2
	return 2.4

## Seconds the launcher needs to reload after a rocket.
static func reload_time(kind: int) -> float:
	if kind == Kind.RPG:
		return 5.0
	return 0.0

## Stagger after being hit. Heavy infantry, braced on a bipod, barely flinch.
static func stagger_time(kind: int) -> float:
	if kind == Kind.HEAVY:
		return 0.06
	return 0.18

## Angular spread of a shot in radians. Bipod-fired rounds group tighter than rifle fire.
static func spread(kind: int) -> float:
	if kind == Kind.HEAVY:
		return deg_to_rad(0.6)
	if kind == Kind.RPG:
		return deg_to_rad(0.3)
	return deg_to_rad(1.1)

## Damage range per round (minimum, maximum). Riflemen keep the original 12-22 range.
static func damage_range(kind: int) -> Vector2:
	if kind == Kind.HEAVY:
		return Vector2(13.0, 17.0)
	if kind == Kind.RPG:
		return Vector2(50.0, 50.0)
	return Vector2(12.0, 22.0)

## Blast radius in metres; only the rocket is an explosive round.
static func blast_radius(kind: int) -> float:
	if kind == Kind.RPG:
		return 2.5
	return 0.0
