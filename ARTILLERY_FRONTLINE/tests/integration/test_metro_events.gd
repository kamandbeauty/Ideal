extends RefCounted
## Metro atmosphere is timed, pooled and harmless, never a combat hazard.

func run(t: TestContext) -> void:
	for stage: int in range(6, 9):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		var station: Node3D = level.geometry
		var pool: EffectPool = level.effects
		for batch_name: String in ["MetroMachineryHousings", "MetroVentGrilles", "MetroCircuitIndicators"]:
			var batch: MultiMeshInstance3D = station.get_node_or_null(batch_name) as MultiMeshInstance3D
			t.check(batch != null and batch.multimesh.instance_count > 0, "station machinery %s is batched" % batch_name)
			if batch:
				t.check(batch.find_children("*", "CollisionObject3D", true, false).is_empty(), "machinery never blocks routes")
		t.equal(station.get("station_event_count"), 0, "no station event has run in the idle view")
		var pool_size: int = pool.pool_size()
		var bursts: int = pool.bursts
		var wall: float = level.defense.wall_health
		var gate: float = level.defense.gate_health
		pool.detail = true
		level.begin_match()
		level.director.stop()
		t.simulate(level, 11.5)
		t.equal(station.get("station_event_count"), 0, "first ambient event waits before starting")
		t.simulate(level, 0.6)
		t.equal(station.get("station_event_count"), 1, "the first vent puff fires on schedule")
		t.equal(station.get("last_station_event"), "vent", "the first effect comes from a vent")
		t.equal(pool.bursts - bursts, 1, "one existing pooled emitter was used")
		t.simulate(level, 20.1)
		t.equal(station.get("station_event_count"), 2, "the circuit fires after a separate interval")
		t.equal(station.get("last_station_event"), "circuit", "the second effect is a circuit spark")
		t.equal(pool.bursts - bursts, 2, "the circuit uses one existing pooled emitter")
		pool.detail = false
		t.simulate(level, 24.1)
		t.equal(station.get("station_event_count"), 3, "the event schedule remains bounded on low quality")
		t.equal(pool.bursts - bursts, 2, "low quality skips decorative particles")
		t.check(pool.pool_size() == pool_size and level.horde.alive_count() == 0, "events create no new emitters or zombies")
		t.check(is_equal_approx(level.defense.wall_health, wall) and is_equal_approx(level.defense.gate_health, gate), "events do not damage the defenses")
		level.over = true
		t.simulate(level, 30.0)
		t.equal(station.get("station_event_count"), 3, "events stop when the match ends")
		await t.discard(level)
	var city: CityLevel = t.make_level(0)
	await t.frames(2)
	t.check(not city.geometry.has_method("step_station_events"), "station effects do not affect city levels")
	await t.discard(city)
