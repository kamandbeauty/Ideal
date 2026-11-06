class_name DamageModel
extends RefCounted


static func blast_damage(base_damage: float, radius: float, distance: float, direct: bool) -> float:
	if base_damage <= 0.0:
		return 0.0
	if direct:
		return base_damage
	if radius <= 0.0 or distance >= radius:
		return 0.0
	return base_damage * (1.0 - clampf(distance / radius, 0.0, 1.0))
