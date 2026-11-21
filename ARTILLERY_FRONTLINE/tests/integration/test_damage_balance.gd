extends RefCounted
## Requested hit counts for the unupgraded twin gun and district health growth.
## Direct, full-damage hits are used: a penetrated round is deliberately weaker.


func run(t: TestContext) -> void:
	# The normal game uses the realistic city rig; its health must match too.
	Zombie.mix_extras = true
	var gun: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	var expected: Dictionary = {&"walker": 2, &"runner": 2, &"brute": 3, &"boss": 50}
	for stage: int in range(6):
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		t.equal(level.director.campaign_stage, stage, "stage %d configures campaign health" % (stage + 1))
		for wave_index: int in level.wave_set.waves.size():
			level.director._start_wave(wave_index)
			t.near(level.horde.health_scale, 1.0, 0.0001, "stage %d wave %d keeps base health" % [stage + 1, wave_index + 1])
			for id: StringName in expected:
				var zombie: Zombie = level.horde.spawn(id, "ring_right", "gate")
				t.check(zombie != null, "%s spawns for damage test" % id)
				if zombie == null:
					continue
				var hits: int = int(expected[id])
				for hit: int in range(hits - 1):
					zombie.take_hit(gun.damage, false, zombie.position, Vector3.FORWARD)
				t.check(zombie.alive, "stage %d wave %d %s survives %d body shots" % [stage + 1, wave_index + 1, id, hits - 1])
				zombie.take_hit(gun.damage, false, zombie.position, Vector3.FORWARD)
				t.check(not zombie.alive, "stage %d wave %d %s falls on body shot %d" % [stage + 1, wave_index + 1, id, hits])
				level.horde.clear()
				if id != &"boss":
					zombie = level.horde.spawn(id, "ring_right", "gate")
					zombie.take_hit(gun.damage * gun.headshot_multiplier, true, zombie.position, Vector3.FORWARD)
					t.check(not zombie.alive, "stage %d wave %d %s falls to one headshot" % [stage + 1, wave_index + 1, id])
					level.horde.clear()
		level.director.stop()
		await t.discard(level)

	# Every stage within a district uses the same multiplier, including all
	# its waves. Growth is gentle and linear, with a hard end-of-campaign
	# expectation so an accidental return to compounding cannot sneak in.
	var expected_scales: Array[float] = [1.0, 1.0, 1.03, 1.06, 1.09, 1.12, 1.15, 1.18, 1.21, 1.24]
	for district: int in range(10):
		var stage: int = district * 3
		var scale: float = expected_scales[district]
		var level: CityLevel = t.make_level(stage)
		await t.frames(2)
		for offset: int in 3:
			t.near(Campaign.zombie_health_scale(stage + offset), scale, 0.0001, "district %d stage %d has the expected health" % [district, offset])
		for wave_index: int in level.wave_set.waves.size():
			level.director._start_wave(wave_index)
			t.near(level.horde.health_scale, scale, 0.0001, "district %d wave %d applies the multiplier" % [district, wave_index + 1])
		var zombie: Zombie = level.horde.spawn(&"walker", "ring_right", "gate")
		t.near(zombie.full_health, zombie.data.max_health * scale, 0.001, "district %d spawns a walker with scaled health" % district)
		level.director.stop()
		level.horde.clear()
		await t.discard(level)

	Zombie.mix_extras = false
