extends RefCounted
## Phase 3.5 balance checks: wave composition, difficulty ramp, completability, spawn pacing,
## and the rule that one shell hurts the emplacement once (direct damage, no second splash).

## Minimum time between two units leaving the same landing craft (infantry step rate).
const MIN_SPAWN_GAP: float = 0.45

func run(t: TestContext) -> void:
	_check_composition(t)
	_check_monotonic(t)
	_check_completable(t)
	await _check_spawn_pacing_and_damage(t)

func _check_composition(t: TestContext) -> void:
	t.equal(WaveManager.ROUNDS.size(), 3, "Campaign has three landing waves")
	for index in range(WaveManager.ROUNDS.size()):
		var setup: Dictionary = WaveManager.ROUNDS[index]
		var wave: String = "Wave %d" % (index + 1)
		t.check(int(setup.get("heavy", 0)) + int(setup.get("rpg", 0)) <= int(setup.soldiers), "%s: heavy and RPG troops replace riflemen inside the soldier count" % wave)
		t.check(int(setup.craft) >= 1, "%s: troops land from at least one landing craft" % wave)
		t.check("repair" in setup.support, "%s: repair support is available" % wave)
		t.check(WaveManager.target_count(setup) > 0, "%s: has targets to destroy" % wave)
	t.check(int(WaveManager.ROUNDS[0].get("bosses", 0)) == 0 and int(WaveManager.ROUNDS[1].get("bosses", 0)) == 0, "The boss tank appears only in the final wave")

func _check_monotonic(t: TestContext) -> void:
	for index in range(1, WaveManager.ROUNDS.size()):
		var before: Dictionary = WaveManager.ROUNDS[index - 1]
		var after: Dictionary = WaveManager.ROUNDS[index]
		var wave: String = "Wave %d" % (index + 1)
		t.check(WaveManager.target_count(after) > WaveManager.target_count(before), "%s fields more targets than the wave before" % wave)
		t.check(int(after.soldiers) >= int(before.soldiers), "%s never fields fewer troops" % wave)
		t.check(_armour_count(after) >= _armour_count(before), "%s never fields less armour" % wave)
		t.check(_aircraft_count(after) >= _aircraft_count(before), "%s never fields fewer aircraft" % wave)
		t.check(int(after.craft) >= int(before.craft), "%s never lands fewer craft" % wave)
		t.check(after.support.size() >= before.support.size(), "%s offers at least the support of the wave before" % wave)

func _check_completable(t: TestContext) -> void:
	var waves := WaveManager.new()
	var finished: Array = []
	waves.mission_finished.connect(func(success): finished.append(success))
	waves.start()
	for index in range(WaveManager.ROUNDS.size()):
		var expected: int = WaveManager.target_count(WaveManager.ROUNDS[index])
		var wave: String = "Wave %d" % (index + 1)
		t.equal(waves.remaining, expected, "%s starts with its full target count" % wave)
		for kill in range(expected):
			waves.register_kill()
		t.equal(waves.remaining, 0, "%s counts down to zero when every target falls" % wave)
		waves.register_kill()
		t.equal(waves.remaining, 0, "%s ignores kills after the wave is clear" % wave)
		waves.tick(WaveManager.INTERMISSION + 0.1)
	t.equal(finished, [true], "Every wave can be cleared in order and the campaign completes")
	waves.free()

func _check_spawn_pacing_and_damage(t: TestContext) -> void:
	var scene: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	# Pacing: units leave one craft in sequence, never closer together than MIN_SPAWN_GAP.
	var landing: LandingCraft = scene.crafts[0]
	var cargo_count: int = landing.cargo.size()
	scene.disembark_queue.clear()
	scene._unload(landing)
	var times: Array[float] = []
	for entry in scene.disembark_queue:
		if entry.craft == landing:
			times.append(float(entry.time))
	t.equal(times.size(), cargo_count, "Every unit in the craft is queued to step ashore")
	var smallest_gap: float = INF
	for index in range(1, times.size()):
		smallest_gap = minf(smallest_gap, times[index] - times[index - 1])
	t.check(times.is_empty() or smallest_gap >= MIN_SPAWN_GAP - 0.0001, "Units leave a craft at least %.2f s apart" % MIN_SPAWN_GAP)
	t.check(times.is_empty() or times[0] >= 0.5, "Nothing steps ashore before the ramp clanks down")
	scene.disembark_queue.clear()
	# Damage: a shell that hits the emplacement deals its damage once, with no second splash.
	var full: float = CoastalController.MAX_HEALTH
	t.check(scene.active, "Mission is live for the damage checks")
	scene.player_health = full
	scene._on_bullet_impact(scene.emplacement + Vector3.UP * 1.1, Vector3.UP, scene.player_hitbox, 150.0, 5.0)
	t.near(scene.player_health, full - 150.0 * CoastalController.DAMAGE_SCALE, 0.001, "A shell that hits the emplacement deals its damage once")
	# A ground burst beside the emplacement still splashes it.
	scene.player_health = full
	scene._on_bullet_impact(scene.emplacement + Vector3(1.0, 0.0, 0.0), Vector3.UP, null, 0.0, 5.0)
	t.near(scene.player_health, full - 120.0 * CoastalController.DAMAGE_SCALE, 0.001, "A ground blast within reach of the emplacement still splashes it")
	scene.player_health = full
	scene.queue_free()
	await t.tree.process_frame

static func _armour_count(setup: Dictionary) -> int:
	return int(setup.get("tanks", 0)) + int(setup.get("apcs", 0)) + int(setup.get("bosses", 0))

static func _aircraft_count(setup: Dictionary) -> int:
	return int(setup.get("helicopters", 0)) + int(setup.get("fighters", 0))
