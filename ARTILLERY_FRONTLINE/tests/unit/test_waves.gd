extends RefCounted
## Wave resources: the shipped siege is valid data and schedules correctly,
## and it is cut into stages without changing a wave.


func run(t: TestContext) -> void:
	_stages(t)
	var siege: WaveSet = Campaign.whole().duplicate()
	siege.waves = siege.waves.slice(0, 9)
	t.check(siege != null and not siege.waves.is_empty(), "the stages add up to one siege")
	var layout: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	var known: Dictionary = {}
	for id: String in ["walker", "runner", "brute", "boss"]:
		known[id] = load("res://resources/zombies/%s.tres" % id)
	t.check(siege.waves.size() >= 5, "the siege has at least five waves")
	t.check(siege.total_zombies() >= 150, "the siege fields at least 150 zombies (got %d)" % siege.total_zombies())
	var total_weight: float = 0.0
	for index: int in siege.waves.size():
		var wave: WaveData = siege.waves[index]
		t.check(wave != null and not wave.groups.is_empty(), "wave %d has spawn groups" % (index + 1))
		# Scheduled health stays positive; the player's chosen balance no longer requires each wave to outweigh the last.
		var weight: float = 0.0
		for group: SpawnGroup in wave.groups:
			if known.has(String(group.zombie)):
				weight += float(group.count) * (known[String(group.zombie)] as ZombieData).max_health * siege.health_scale(index)
		total_weight += weight
		t.check(wave.hint_key == "" or Loc.TEXT.en.has(wave.hint_key), "wave %d's hint has its text" % (index + 1))
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
	t.check(total_weight > 0.0, "the siege fields positive total health")
	# How the siege unfolds: walkers alone, then runners, then brutes, and one boss to end it.
	var first_with: Dictionary = {}
	for index: int in siege.waves.size():
		for id: String in known:
			if not first_with.has(id) and siege.waves[index].count_of(StringName(id)) > 0:
				first_with[id] = index
	t.equal(first_with.get("walker", -1), 0, "walkers open the siege")
	t.equal(siege.waves[0].total(), siege.waves[0].count_of(&"walker"), "and have the first wave to themselves")
	t.check(first_with.get("runner", 99) > 0 and first_with.get("runner", 99) < first_with.get("brute", 0), "runners come next, brutes after them")
	t.equal(first_with.get("boss", -1), siege.waves.size() - 1, "the boss comes only in the last wave")
	t.equal(siege.waves[siege.waves.size() - 1].count_of(&"boss"), 1, "and there is one of it")
	var runner: ZombieData = known.runner
	var machine_gun: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	t.check(runner.max_health * siege.health_scale(siege.waves.size() - 1) < machine_gun.damage * 2.0,
		"two rounds still drop a runner in the last wave, as the hint promises")

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


## The siege is played a stage at a time. The first is three waves; each later one opens as hard as the wave it starts with.
func _stages(t: TestContext) -> void:
	t.equal(Campaign.count(), 30, "ten districts each have three stages")
	var first: WaveSet = Campaign.waves(0)
	t.equal(first.waves.size(), 3, "the first stage is three waves")
	t.equal(first.waves_before, 0, "and starts the siege")
	t.check(first.waves[0].count_of(&"brute") + first.waves[1].count_of(&"brute") + first.waves[2].count_of(&"brute") == 0
		and first.waves[2].count_of(&"boss") == 0, "it fields no brute and no boss")
	var before: int = 0
	var zombies: int = 0
	var whole: WaveSet = Campaign.whole()
	for stage: int in Campaign.count():
		var part: WaveSet = Campaign.waves(stage)
		t.check(part != null and part.waves.size() == 3, "stage %d has exactly three waves" % (stage + 1))
		t.equal(part.waves_before, before, "stage %d knows how many waves came before it" % (stage + 1))
		var difficulty_start: int = part.difficulty_waves_before if part.difficulty_waves_before >= 0 else before
		var reference := WaveSet.new()
		reference.speed_growth = part.speed_growth
		reference.health_growth = part.health_growth
		t.near(part.health_scale(0), reference.health_scale(difficulty_start), 0.0001, "stage %d keeps its prior difficulty baseline" % (stage + 1))
		t.near(part.speed_scale(0), reference.speed_scale(difficulty_start), 0.0001, "stage %d keeps its prior opening speed" % (stage + 1))
		var old_last: int = difficulty_start + (1 if stage == 2 else 2)
		t.near(part.speed_scale(2), reference.speed_scale(old_last), 0.0001,
			"stage %d retains its original final-wave speed" % (stage + 1))
		for index: int in part.waves.size():
			t.check(part.waves[index].total() == whole.waves[before + index].total(), "stage %d wave %d is that wave, unchanged" % [stage + 1, index + 1])
			t.equal(Campaign.place_of(before + index + 1), Vector2i(stage + 1, index + 1), "wave %d of the siege is found in its stage" % (before + index + 1))
		before += part.waves.size()
		zombies += part.total_zombies()
	t.equal(before, Campaign.total_waves(), "the stages hold every wave")
	t.equal(zombies, Campaign.total_zombies(), "and every zombie")
	var hospital: LevelLayout = load("res://resources/levels/hospital_layout.tres")
	var hospital_waves: WaveSet = Campaign.waves(3)
	t.check(Campaign.scene(3).ends_with("hospital_siege.tscn") and Campaign.scene(2).ends_with("city_siege.tscn"), "the fourth stage selects its own scene")
	t.equal(hospital_waves.waves_before, 9, "hospital follows the three city stages")
	var metro: LevelLayout = load("res://resources/levels/metro_layout.tres")
	for stage: int in range(3, 9):
		var layout: LevelLayout = hospital if stage < 6 else metro
		t.check(Campaign.scene(stage).contains("hospital") if stage < 6 else Campaign.scene(stage).contains("metro"), "stage has the right district scene")
		for wave: WaveData in Campaign.waves(stage).waves:
			for group: SpawnGroup in wave.groups:
				for route: String in group.routes:
					t.check(layout.has_route(route), "district wave route exists: " + route)
	var city: LevelLayout = load("res://resources/levels/city_siege_layout.tres")
	for stage: int in range(9, Campaign.count()):
		t.equal(Campaign.district(stage), stage / 3, "later stage belongs to its district")
		var expected: String = "industrial" if stage < 12 else ("bazaar" if stage < 15 else ("terminal" if stage < 18 else ("residential" if stage < 21 else ("stadium" if stage < 24 else "city"))))
		t.check(Campaign.scene(stage).contains(expected), "later district selects its scene")
		for wave: WaveData in Campaign.waves(stage).waves:
			for group: SpawnGroup in wave.groups:
				for route: String in group.routes:
					t.check(city.has_route(route), "later wave route exists: " + route)
	t.equal(Campaign.open_stages(0), Campaign.count(), "a new player may start any stage")
	t.equal(Campaign.open_stages(1), Campaign.count(), "all stages remain available")
	t.equal(Campaign.open_stages(Campaign.count()), Campaign.count(), "and nothing opens past the last")
	t.equal(Campaign.waves(99), Campaign.waves(Campaign.count() - 1), "an impossible stage number falls back to the last")
