extends TestCase
## Tower costs, upgrade steps and per-level stats.


func test_three_towers_are_defined() -> void:
	equal(TowerData.TYPES.size(), 3, "three tower types")
	for kind in TowerData.TYPES:
		check(TowerData.has_type(kind), "missing tower data for " + kind)
		equal(TowerData.max_level(kind), TowerData.MAX_LEVEL, "max level for " + kind)
		check(TowerData.build_cost(kind) > 0, "build cost for " + kind)


func test_costs_rise_with_level() -> void:
	for kind in TowerData.TYPES:
		var previous := 0
		for level in range(1, TowerData.max_level(kind) + 1):
			var cost := int(TowerData.stats(kind, level).get("cost", 0))
			check(cost > previous, "%s level %d must cost more" % [kind, level])
			previous = cost
		equal(TowerData.upgrade_cost(kind, TowerData.max_level(kind)), 0, "no upgrade past the top")


func test_stats_are_sane() -> void:
	for kind in TowerData.TYPES:
		var previous_damage := 0.0
		for level in range(1, TowerData.max_level(kind) + 1):
			var damage := TowerData.damage_for(kind, level)
			check(damage > 0.0, "%s level %d deals damage" % [kind, level])
			check(damage > previous_damage, "%s level %d hits harder" % [kind, level])
			previous_damage = damage
			check(TowerData.range_for(kind, level) > 2.0, "%s has a usable range" % kind)
			check(TowerData.cooldown_for(kind, level) > 0.05, "%s has a cooldown" % kind)


func test_sell_value_is_a_fraction_of_investment() -> void:
	for kind in TowerData.TYPES:
		for level in range(1, TowerData.max_level(kind) + 1):
			var invested := TowerData.invested(kind, level)
			var refund := TowerData.sell_value(kind, level)
			check(refund < invested, "%s refund must be below the investment" % kind)
			check(refund > 0, "%s refund must be positive" % kind)
	equal(TowerData.invested("sentry", 1), 60, "sentry level 1 investment")
	equal(TowerData.invested("sentry", 2), 140, "sentry level 2 investment")
	equal(TowerData.sell_value("sentry", 1), 36, "sentry level 1 refund")


func test_unknown_tower_is_handled() -> void:
	check(not TowerData.has_type("laser"), "unknown tower rejected")
	equal(TowerData.stats("laser", 1), {}, "unknown tower has no stats")
	equal(TowerData.build_cost("laser"), 0, "unknown tower costs nothing")
	equal(TowerData.max_level("laser"), 0, "unknown tower has no levels")
	equal(TowerData.upgrade_cost("laser", 1), 0, "unknown tower cannot be upgraded")


func test_level_is_clamped() -> void:
	equal(
		TowerData.damage_for("sentry", 99),
		TowerData.damage_for("sentry", 3),
		"levels above the top clamp"
	)
	equal(
		TowerData.damage_for("sentry", -4),
		TowerData.damage_for("sentry", 1),
		"levels below one clamp"
	)
