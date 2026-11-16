extends TestCase
## Rendering-only feedback: bounded pools, real service gates, cleanup and
## original pictograms. Actual CustomerFlow lifecycle checks run in traffic_check.


func test_every_facility_has_its_own_lightweight_pictogram() -> void:
	var textures: Array[Texture2D] = []
	for id in BusinessData.ids():
		check(ServiceEffects.ICONS.has(id), id + " has a service pictogram")
		var texture: Texture2D = ServiceEffects.ICONS[id]
		equal(texture.get_width(), 64, id + " icon is only 64px")
		check(not textures.has(texture), id + " has a distinct symbol")
		textures.append(texture)
		var nights: Array[StandardMaterial3D] = []
		var facility := BusinessDecor.build_facility(id, 50, 1, nights)
		var emblem := facility.get_node("ServiceEmblem") as Sprite3D
		equal(emblem.texture, texture, id + " facade matches its service indicator")
		check(emblem.position.x < 1.70 and emblem.position.y < 3.9, "enamel sign stays inside the existing solid")
		facility.free()


func test_fixed_pool_never_adds_nodes_while_servicing() -> void:
	for id in BusinessData.ids():
		var effects := ServiceEffects.new()
		effects.setup(id, "camper", "high")
		var before := _node_count(effects)
		check(before <= 13, id + " has a strict node budget")
		check(not _has_simulation_node(effects), id + " contains no physics, timers or lights")
		for i in 180:
			effects.tick(1.0 / 60.0, true, float(i) / 180.0)
		equal(_node_count(effects), before, id + " uses a pool, not spawned particle nodes")
		equal(effects.activation_count, 1, "a service stays one activation, not one per frame")
		effects.free()


func test_quality_changes_resize_only_the_particle_pool() -> void:
	equal(Quality.service_particle_count("low"), 0, "low skips decorative particles")
	equal(Quality.service_particle_count("medium"), 6, "medium has six pooled particles")
	equal(Quality.service_particle_count("high"), 10, "high has ten pooled particles")
	var effects := ServiceEffects.new()
	effects.setup("gas_station", "car", "high")
	var before := _node_count(effects)
	for preset in ["high", "low", "medium", "invalid", "low"]:
		effects.set_quality(preset)
		effects.tick(0.1, true, 0.5)
		equal(effects.particle_count(), Quality.service_particle_count(preset), "live preset has the right budget")
		equal(_node_count(effects), before, "quality never rebuilds the vehicle or effect nodes")
		check(effects.visible and effects.has_node("ServiceIcon"), "low still communicates service")
		check(effects.has_node("FuelHose"), "the connected hose survives a quality change")
	effects.free()


func test_service_gate_hides_everything_immediately() -> void:
	var effects := ServiceEffects.new()
	effects.setup("car_wash", "monster", "high")
	effects.tick(3.0, false, 0.0)
	check(not effects.visible and not effects.servicing, "a reservation has no visible service")
	equal(effects.activation_count, 0, "driving does not start an animation")
	effects.tick(0.1, true, 0.2)
	check(effects.visible and effects.servicing, "parking starts service feedback")
	var roller := effects.get_node("WashRollerLeft") as Node3D
	var angle := roller.rotation.y
	effects.tick(0.1, true, 0.4)
	check(not is_equal_approx(angle, roller.rotation.y), "car-wash brushes really spin")
	effects.tick(0.0, false, 1.0)
	check(not effects.visible and not effects.servicing, "payment hides brushes before reversing")
	equal(effects.activation_count, 1, "payment does not create another service")
	effects.free()


func test_indicators_clear_the_car_and_overhead_equipment() -> void:
	for kind in ["car", "suv", "pickup", "camper", "monster"]:
		for id in BusinessData.ids():
			var height := ServiceEffects.indicator_height(id, kind)
			check(height > ServiceEffects.vehicle_top(kind) + 0.30, "indicator clears " + kind)
			if id == "gas_station":
				check(height > 2.30, "fuel indicator clears the canopy")
			elif id == "car_wash" or id == "auto_service":
				check(height > 2.21, "indicator clears the service gantry")


func test_pool_transforms_stay_finite_for_hitches_and_bad_progress() -> void:
	for id in BusinessData.ids():
		var effects := ServiceEffects.new()
		effects.setup(id, "monster", "high")
		for delta in [-1.0, 0.0, 0.016, 200.0]:
			effects.tick(delta, true, 100.0)
			var pool := (effects.get_node("PooledServiceParticles") as MultiMeshInstance3D).multimesh
			for i in pool.instance_count:
				var pose := pool.get_instance_transform(i)
				check(pose.is_finite(), "particle transforms remain finite")
				check(pose.origin.length() < 2.5, "particles remain within their service bay")
				check(pose.basis.determinant() > 0.0, "pooled spheres have positive scale")
		effects.free()


func test_departing_car_owns_and_frees_all_its_feedback() -> void:
	var car := Node3D.new()
	var effects := ServiceEffects.new()
	effects.setup("electric_charger", "car", "medium")
	car.add_child(effects)
	var reference := weakref(effects)
	check(effects.has_node("ChargingCable"), "EV customers get a charging cable")
	car.free()
	equal(reference.get_ref(), null, "freeing a car also frees every service effect")


func test_painted_bay_numbers_switch_language_without_rebuilding() -> void:
	var bays := ServiceBayVisuals.build("gas_station", 3, "fa")
	var number := bays.get_node("BayNumber_0") as Label3D
	equal(number.text, "۰۱", "Persian bay numbers use Persian digits")
	var pose := number.transform
	ServiceBayVisuals.localize(bays, "en")
	equal(number.text, "01", "English bay numbers remain zero-padded")
	ServiceBayVisuals.localize(bays, "fa")
	equal(number.text, "۰۱", "live language switching updates the same label")
	equal(number.transform, pose, "language cannot move a reserved bay")
	bays.free()


func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _node_count(child)
	return count


func _has_simulation_node(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is Timer or node is Light3D:
		return true
	for child in node.get_children():
		if _has_simulation_node(child):
			return true
	return false
