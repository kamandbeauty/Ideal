extends RefCounted
## Wave resources: the shipped siege is valid data and schedules correctly.


func run(t: TestContext) -> void:
	var siege: WaveSet = load("res://resources/waves/city_siege_waves.tres")
	t.check(siege != null, "city_siege_waves.tres loads as WaveSet")
	var layout: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	var known: Dictionary = {"walker": load("res://resources/zombies/walker.tres")}
	t.check(siege.waves.size() >= 5, "the siege has at least five waves")
	t.check(siege.total_zombies() >= 150, "the siege fields at least 150 zombies (got %d)" % siege.total_zombies())
	var previous: int = 0
	var growing: bool = true
	for index: int in siege.waves.size():
		var wave: WaveData = siege.waves[index]
		t.check(wave != null and not wave.groups.is_empty(), "wave %d has spawn groups" % (index + 1))
		if wave.total() <= previous:
			growing = false
		previous = wave.total()
		t.check(wave.max_alive >= 10 and wave.intermission >= 0.0, "wave %d has sane limits" % (index + 1))
		t.check(wave.resupply_rockets >= 0 and wave.resupply_grenades >= 0, "wave %d hands out no negative supplies" % (index + 1))
		var valid: bool = true
		for group: SpawnGroup in wave.groups:
			if not known.has(String(group.zombie)):
				valid = false
			if not ["gate", "wall", "any"].has(group.target):
				valid = false
			if group.count < 1 or group.interval <= 0.0 or group.burst < 1 or group.start_time < 0.0:
				valid = false
			for route: String in group.routes:
				if not layout.has_route(route):
					valid = false
		t.check(valid, "wave %d only uses known zombies, routes and targets" % (index + 1))
		var schedule: Array = wave.schedule()
		t.equal(schedule.size(), wave.total(), "wave %d schedules every zombie" % (index + 1))
		var ordered: bool = true
		for entry: int in range(1, schedule.size()):
			if schedule[entry][0] < schedule[entry - 1][0]:
				ordered = false
		t.check(ordered, "wave %d's schedule is in time order" % (index + 1))
	t.check(growing, "each wave is bigger than the one before")

	# Hardening from wave to wave.
	t.near(siege.health_scale(0), 1.0, 0.0001, "the first wave has base health")
	t.check(siege.health_scale(4) > siege.health_scale(1), "health grows with the wave number")
	t.check(siege.speed_scale(4) > 1.0 and siege.speed_scale(4) < 1.5, "speed grows gently")

	# Group timing, including bursts.
	var group := SpawnGroup.new()
	group.count = 6
	group.start_time = 2.0
	group.interval = 1.5
	group.burst = 2
	group.routes = PackedStringArray(["ring_left"])
	group.target = "wall"
	var wave := WaveData.new()
	var groups: Array[SpawnGroup] = [group]
	wave.groups = groups
	var times: Array = []
	for entry: Array in wave.schedule():
		times.append(entry[0])
	t.equal(times, [2.0, 2.0, 3.5, 3.5, 5.0, 5.0], "a burst of two spawns pairs at each interval")
	t.equal(String(wave.schedule()[0][3]), "wall", "the schedule carries the group's target")
	t.equal(wave.total(), 6, "total counts the group")

	# Zombie data.
	var walker: ZombieData = known.walker
	t.check(walker != null and walker.scene != null, "walker.tres loads with its scene")
	t.check(walker.max_health > 0.0 and walker.speed > 0.0 and walker.attack_damage > 0.0, "walker numbers are positive")
	t.check(walker.attack_hit_point > 0.0 and walker.attack_hit_point < 1.0, "the blow lands inside the swing")
	var weapon: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	t.check(weapon.damage * weapon.headshot_multiplier >= walker.max_health, "one headshot kills a walker")
	t.check(weapon.damage < walker.max_health, "a walker survives one body shot")
