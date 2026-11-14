extends TestCase
## The visual growth system: every business builds four real prop stages, and
## the day cycle keeps the sun and the phases honest.


func test_every_business_has_four_stages() -> void:
	equal(BusinessDecor.STAGE_LEVELS.size(), 4, "four visual stages ship")
	for id in BusinessData.ids():
		for stage in BusinessDecor.STAGE_LEVELS:
			var node := BusinessDecor.build_stage(id, stage, BusinessData.accent(id))
			check(node.get_child_count() > 0, "%s stage %d has no props" % [id, stage])
			node.free()


func test_stages_add_more_props_as_they_grow() -> void:
	var small := BusinessDecor.build_stage("gas_station", 2, Color.WHITE)
	var big := BusinessDecor.build_stage("gas_station", 5, Color.WHITE)
	check(
		big.get_child_count() >= small.get_child_count(),
		"a later stage should not be emptier"
	)
	small.free()
	big.free()


func test_emissive_props_register_for_night() -> void:
	var node := BusinessDecor.build_stage("gas_station", 4, Color.WHITE)
	var materials: Array = node.get_meta("night_materials", [])
	check(materials.size() > 0, "lit props must register their materials")
	node.free()


func test_totems_and_wash_are_dressed() -> void:
	for id in ["restaurant", "store", "workshop", "motel", "car_wash"]:
		var node := BusinessDecor.build_stage(id, 5, Color.WHITE)
		check(node.get_child_count() >= 2, id + " needs a visible final stage")
		node.free()


func test_day_cycle_phases() -> void:
	var cycle := DayCycle.new()
	cycle.set_time(0.25)
	almost(float(cycle.elevation()), 1.0, "noon has the highest sun", 0.001)
	equal(cycle.phase(), "noon", "0.25 is noon")
	check(not cycle.is_night(), "noon is not night")

	cycle.set_time(0.75)
	almost(float(cycle.elevation()), -1.0, "midnight has the lowest sun", 0.001)
	check(cycle.is_night(), "midnight is night")

	cycle.set_time(0.05)
	equal(cycle.phase(), "morning", "0.05 is morning")
	cycle.set_time(0.45)
	equal(cycle.phase(), "evening", "0.45 is evening")

	cycle.set_time(1.3)
	check(cycle.time >= 0.0 and cycle.time < 1.0, "time wraps into one day")
	cycle.free()
