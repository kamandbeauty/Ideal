extends RefCounted
## Checks for the cleanup and guidance changes: destroyed units leave the field 5 s after death (a landing craft
## keeps its hull while troops are still queued to leave it), an aircraft blast in the air leaves no ground scar,
## the rocket launcher is a guided intercept missile that steers to the nearest hostile, and the bazooka stays unguided.

## Seconds of flight simulated for the guided-missile check, and the step used.
const FLIGHT_TIME: float = 2.0
const STEP: float = 1.0 / 60.0
## Missile speed used in the trajectory check: the rocket launcher's muzzle speed (coastal_weapon.gd).
const ROCKET_SPEED: float = 115.0

func run(t: TestContext) -> void:
	_check_guided_missile_reaches_off_axis_target(t)
	_check_bazooka_unguided(t)
	_check_no_scar_for_air_blast(t)
	await _check_guide_picks_nearest_living(t)
	await _check_dead_units_removed_after_delay(t)

func _check_guided_missile_reaches_off_axis_target(t: TestContext) -> void:
	var goal := Vector3(60.0, 1.0, -40.0)
	var guided: float = _closest_approach(t.tree, goal, 3.0)
	var unguided: float = _closest_approach(t.tree, goal, 0.0)
	t.check(guided < 3.0, "The intercept missile steers onto a target 74 m away off its line (closest %.1f m)" % guided)
	t.check(unguided > 40.0, "Without guidance the same missile flies past the target (closest %.1f m)" % unguided)

## Flies one missile from the emplacement toward `goal` and returns its closest approach to the goal.
func _closest_approach(tree: SceneTree, goal: Vector3, turn_rate: float) -> float:
	var bullet := CoastalBullet.new()
	var target := goal
	var guide := func(_from: Vector3) -> Vector3: return target
	var host := Node3D.new()
	host.name = "GuidanceHost"
	host.add_child(bullet)
	tree.root.add_child(host)
	var excluded: Array[RID] = []
	bullet.launch(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -ROCKET_SPEED), 170.0, 9.0, 7, excluded, guide, turn_rate)
	var closest: float = INF
	var clock: float = 0.0
	while clock < FLIGHT_TIME and bullet.active:
		bullet._physics_process(STEP)
		closest = minf(closest, bullet.global_position.distance_to(goal))
		clock += STEP
	host.queue_free()
	return closest

func _check_bazooka_unguided(t: TestContext) -> void:
	t.check(CoastalController.GUIDED_TURN_RATE.has("rocket"), "The rocket launcher is the guided intercept missile")
	t.check(not CoastalController.GUIDED_TURN_RATE.has("bazooka"), "The bazooka stays an unguided round")

## A blast in the air must not leave a ground scar (the crater decal would hang in the sky).
func _check_no_scar_for_air_blast(t: TestContext) -> void:
	var pool := EffectPool.new()
	pool.name = "ScarTest"
	t.tree.root.add_child(pool)
	var before: int = _visible_scars(pool)
	pool.explode(Vector3(0.0, 40.0, -80.0), Vector3.UP, 8.0, 3.0, false, false)
	t.equal(_visible_scars(pool), before, "An aircraft blast in the air leaves no ground scar")
	pool.explode(Vector3(0.0, 0.0, -80.0), Vector3.UP, 8.0, 0.0)
	t.equal(_visible_scars(pool), before + 1, "A blast on the ground leaves one scar")
	pool.queue_free()

static func _visible_scars(pool: EffectPool) -> int:
	var count: int = 0
	for scar in pool.craters:
		if scar.visible:
			count += 1
	return count

## The guided missile homes on the nearest living hostile; a destroyed unit is not a target.
func _check_guide_picks_nearest_living(t: TestContext) -> void:
	var scene: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	scene.disembark_all_now()
	var from: Vector3 = scene.emplacement + Vector3.UP * 2.0
	var first: Vector3 = scene._guide_point(from)
	t.check(not is_inf(first.x), "A guided missile has a target while hostiles are alive")
	var expected: Vector3 = _nearest_centre(scene, from)
	t.check(first.distance_to(expected) < 0.01, "The missile homes on the nearest living hostile")
	var nearest = _nearest_node(scene, from)
	if nearest != null:
		# A unit that cannot be hit is not chased: the missile moves on to the next hittable hostile.
		nearest.collision_layer = 0
		var unhittable: Vector3 = scene._guide_point(from)
		t.check(unhittable.distance_to(first) > 0.01, "The missile does not home on a unit it cannot hit")
		nearest.collision_layer = 2
		nearest.receive_damage(100000.0)
		var next_target: Vector3 = scene._guide_point(from)
		t.check(next_target.distance_to(first) > 0.01, "After its target is destroyed the missile picks another hostile")
	scene.queue_free()
	await t.tree.process_frame

static func _centre_of(node: Node3D) -> Vector3:
	var lift: float = 1.2 if node is EnemyAircraft else 1.0
	return node.global_position + Vector3.UP * lift

static func _nearest_node(scene: CoastalController, from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_distance: float = INF
	for group in [scene.soldiers, scene.vehicles, scene.aircraft, scene.crafts]:
		for node in group:
			if is_instance_valid(node) and not node.is_dead() and node.collision_layer != 0:
				var distance: float = _centre_of(node).distance_to(from)
				if distance < best_distance:
					best_distance = distance
					best = node
	return best

static func _nearest_centre(scene: CoastalController, from: Vector3) -> Vector3:
	var node: Node3D = _nearest_node(scene, from)
	return _centre_of(node) if node != null else Vector3.INF

func _check_dead_units_removed_after_delay(t: TestContext) -> void:
	var scene: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	scene.disembark_all_now()
	var soldier: EnemySoldier = scene.soldiers[0]
	soldier.receive_damage(100000.0)
	t.check(soldier.is_dead(), "A soldier dies from a lethal hit")
	scene._tick_removals(4.0)
	t.check(scene.soldiers.has(soldier), "A destroyed soldier is still on the field 4 s after death")
	scene._tick_removals(1.5)
	t.check(not scene.soldiers.has(soldier), "A destroyed soldier is removed 5 s after death")
	t.check(not is_instance_valid(soldier) or soldier.is_queued_for_deletion(), "The removed soldier is freed")
	scene.queue_free()
	await t.tree.process_frame
	# A craft is checked on a fresh mission, before its troops have landed.
	var fresh: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(fresh)
	await t.tree.process_frame
	await t.tree.process_frame
	var boat: LandingCraft = fresh.crafts[0]
	# Grounded and unloaded, but the queue is not drained: the troops are still coming off the hull.
	boat.ground_now()
	fresh._unload(boat)
	t.check(not fresh.disembark_queue.is_empty(), "A grounded craft has its troops queued to come ashore")
	boat.receive_damage(100000.0)
	t.check(not fresh.disembark_queue.is_empty(), "A sunk craft still has its troops queued to come ashore")
	fresh._tick_removals(6.0)
	t.check(fresh.crafts.has(boat), "A sunk craft keeps its hull while its troops are still queued")
	fresh.disembark_queue.clear()
	fresh._tick_removals(0.6)
	t.check(not fresh.crafts.has(boat), "A sunk craft is removed once its cargo has left")
	fresh.queue_free()
	await t.tree.process_frame
