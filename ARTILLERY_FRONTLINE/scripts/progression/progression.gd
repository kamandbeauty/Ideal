class_name Progression
extends RefCounted

static func award(data: Dictionary, mission: MissionData, result: Dictionary) -> Dictionary:
	var next: Dictionary = data.duplicate(true)
	var first_clear: bool = not mission.id in next.completed
	var old: Dictionary = next.records.get(mission.id, {"stars": 0, "accuracy": 0.0, "time": 9999.0, "shots": 9999})
	var new_stars: int = int(result.get("stars", 0))
	var star_gain: int = maxi(0, new_stars - int(old.stars))
	next.coins += int(result.get("coins", 0))
	next.stars += star_gain
	next.upgrade_points += int(result.get("points", 0)) if first_clear else 0
	if first_clear:
		next.completed.append(mission.id)
	var order: Array[String] = ["sr01", "sr02", "sr03", "sr04", "sr05"]
	var index: int = order.find(mission.id)
	if index >= 0 and index + 1 < order.size() and not order[index + 1] in next.unlocked:
		next.unlocked.append(order[index + 1])
	if new_stars > int(old.stars) or (new_stars == int(old.stars) and float(result.get("time", 9999)) < float(old.time)):
		next.records[mission.id] = {"stars": new_stars, "accuracy": float(result.get("accuracy", 0.0)), "time": float(result.get("time", 0.0)), "shots": int(result.get("shots", 0))}
	return next

static func buy_upgrade(data: Dictionary, upgrade: UpgradeData) -> Dictionary:
	var next: Dictionary = data.duplicate(true)
	var level: int = int(next.upgrades.get(upgrade.id, 0))
	var price: int = upgrade.cost(level)
	if level >= upgrade.maximum_level or next.coins < price or next.upgrade_points < upgrade.points_per_level:
		return {"success": false, "data": data, "reason": "upgrade_insufficient"}
	next.coins -= price
	next.upgrade_points -= upgrade.points_per_level
	next.upgrades[upgrade.id] = level + 1
	return {"success": true, "data": next, "reason": "upgrade_installed"}
