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


static func range_factor(distance: float, effective_range: float) -> float:
	if effective_range <= 0.0 or distance <= effective_range:
		return 1.0
	return clampf(1.0 - 0.5 * (distance - effective_range) / effective_range, 0.5, 1.0)
