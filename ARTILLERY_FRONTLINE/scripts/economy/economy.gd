class_name Economy
extends RefCounted

static func mission_reward(base: int, accuracy: float, shots: int, supply: int, elapsed: float, par_time: float, optional_done: bool) -> Dictionary:
	var precision_bonus: int = roundi(clampf(accuracy, 0.0, 100.0) * 1.5)
	var efficiency_bonus: int = roundi(80.0 * maxf(0.0, 1.0 - float(shots) / maxf(1.0, supply)))
	var speed_bonus: int = roundi(70.0 * clampf(1.0 - elapsed / maxf(1.0, par_time * 2.0), 0.0, 1.0))
	var stars: int = 1
	if accuracy >= 45.0:
		stars += 1
	if accuracy >= 70.0 and elapsed <= par_time:
		stars += 1
	return {"coins": base + precision_bonus + efficiency_bonus + speed_bonus + (75 if optional_done else 0), "stars": stars, "points": 1 + (1 if stars == 3 else 0)}
