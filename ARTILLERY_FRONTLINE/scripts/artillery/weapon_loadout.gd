class_name WeaponLoadout
extends RefCounted

var weapon: WeaponData
var ammunition: Dictionary = {}
var counts: Dictionary = {}
var selected: String = "he"
var upgrades: Dictionary = {}

func _init(data: WeaponData, ammo_resources: Array[AmmunitionData], supply: Dictionary, levels: Dictionary) -> void:
	weapon = data
	upgrades = levels.duplicate()
	for ammo in ammo_resources:
		if ammo.id in weapon.compatible_ammunition:
			ammunition[ammo.id] = ammo
			counts[ammo.id] = maxi(0, int(supply.get(ammo.id, ammo.supply)) + 2 * int(levels.get("capacity", 0)))
	if not ammunition.has(selected) and not ammunition.is_empty():
		selected = ammunition.keys()[0]

func current_ammo() -> AmmunitionData:
	return ammunition.get(selected)

func select(id: String) -> bool:
	if not ammunition.has(id):
		return false
	selected = id
	return true

func consume() -> AmmunitionData:
	var ammo: AmmunitionData = current_ammo()
	if ammo == null or int(counts.get(selected, 0)) <= 0:
		return null
	counts[selected] -= 1
	return ammo

func total_remaining() -> int:
	var total: int = 0
	for value in counts.values():
		total += int(value)
	return total

func damage_multiplier() -> float:
	return 1.0 + 0.08 * int(upgrades.get("damage", 0))

func velocity() -> float:
	return weapon.muzzle_velocity * (1.0 + 0.05 * int(upgrades.get("range", 0))) * current_ammo().velocity_multiplier

func reload_seconds() -> float:
	return weapon.reload_duration * (1.0 - 0.10 * int(upgrades.get("reload", 0)))

func dispersion() -> float:
	return weapon.accuracy_degrees * pow(0.82, int(upgrades.get("accuracy", 0)))
