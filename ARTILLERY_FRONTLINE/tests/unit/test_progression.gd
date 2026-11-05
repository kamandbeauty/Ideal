extends RefCounted
func run(t: TestContext) -> void:
	var mission: MissionData = load("res://resources/missions/sr01.tres")
	var data: Dictionary = SaveManager.defaults()
	var reward: Dictionary = Economy.mission_reward(250, 100, 2, 15, 40, 90, true)
	reward["success"] = true
	reward["time"] = 40.0
	reward["accuracy"] = 100.0
	reward["shots"] = 2
	var next: Dictionary = Progression.award(data, mission, reward)
	t.equal(next.stars, 3, "Three-star performance")
	t.check(next.coins > 250 + 300, "Performance reward includes bonuses")
	t.check("sr02" in next.unlocked, "Next mission unlocked")
	var replay: Dictionary = Progression.award(next, mission, reward)
	t.equal(replay.stars, next.stars, "Replay cannot farm stars")
	t.equal(replay.upgrade_points, next.upgrade_points, "Replay cannot farm first-clear points")
	var upgrade: UpgradeData = load("res://resources/upgrades/reload.tres")
	var purchase: Dictionary = Progression.buy_upgrade(replay, upgrade)
	t.check(purchase.success, "Affordable upgrade purchased")
	t.equal(purchase.data.upgrades.reload, 1, "Upgrade level persisted in data")
	t.equal(purchase.data.coins, replay.coins - upgrade.cost(0), "Exact upgrade price charged")
	var poor: Dictionary = SaveManager.defaults()
	poor.coins = 0
	t.check(not Progression.buy_upgrade(poor, upgrade).success, "Cannot overspend")
