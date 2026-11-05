class_name DamageSystem
extends RefCounted

static func calculate(base_damage: float, distance: float, radius: float, armor: float = 0.0, direct_hit: bool = false, direct_bonus: float = 1.0) -> float:
	if base_damage <= 0.0 or distance < 0.0:
		return 0.0
	var attenuation: float = 1.0
	if not direct_hit:
		if radius <= 0.0 or distance > radius:
			return 0.0
		attenuation = pow(1.0 - distance / radius, 1.35)
	var penetration: float = clampf(armor * (0.45 if direct_hit else 1.0), 0.0, 0.9)
	return maxf(0.0, base_damage * attenuation * (direct_bonus if direct_hit else 1.0) * (1.0 - penetration))
