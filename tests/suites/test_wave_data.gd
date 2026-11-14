extends TestCase
## Wave composition, spawn schedules and rewards.


func test_all_waves_are_well_formed() -> void:
	equal(WaveData.TOTAL, 10, "ten waves are shipped")
	for index in range(1, WaveData.TOTAL + 1):
		var wave := WaveData.get_wave(index)
		var groups: Array = wave["groups"]
		check(not groups.is_empty(), "wave %d has enemies" % index)
		for group in groups:
			check(EnemyData.has_type(str(group["type"])), "wave %d has a known enemy" % index)
			check(int(group["count"]) > 0, "wave %d group has a count" % index)
			check(float(group["interval"]) > 0.0, "wave %d group has an interval" % index)
			check(float(group["delay"]) >= 0.0, "wave %d group has a delay" % index)
		equal(int(wave["total_enemies"]), WaveData.count_enemies(groups), "wave %d enemy count" % index)
		check(int(wave["reward"]) > 0, "wave %d pays out" % index)


func test_difficulty_grows() -> void:
	var previous := 0
	for index in range(1, WaveData.TOTAL + 1):
		var total := int(WaveData.get_wave(index)["total_enemies"])
		check(total > previous, "wave %d is bigger than the last" % index)
		previous = total
	check(WaveData.reward(10) > WaveData.reward(1), "the last wave pays more")


func test_schedule_is_sorted_and_complete() -> void:
	for index in range(1, WaveData.TOTAL + 1):
		var schedule := WaveData.schedule(index)
		var wave := WaveData.get_wave(index)
		equal(schedule.size(), int(wave["total_enemies"]), "schedule covers wave %d" % index)
		var previous_time := -1.0
		for entry in schedule:
			var time := float(entry["time"])
			check(time >= previous_time, "schedule of wave %d is ordered" % index)
			check(EnemyData.has_type(str(entry["type"])), "schedule of wave %d has known enemies" % index)
			previous_time = time
		check(previous_time >= 0.0, "wave %d schedules something" % index)


func test_bosses_arrive_on_the_fifth_and_tenth_wave() -> void:
	for index in [5, 10]:
		var types: Array = []
		for group in WaveData.get_wave(index)["groups"]:
			types.append(str(group["type"]))
		check(types.has("boss"), "wave %d brings a boss" % index)
		check(WaveData.is_boss_wave(index), "wave %d is a boss wave" % index)
	for index in [1, 2, 3, 4, 6, 7, 8, 9]:
		check(not WaveData.is_boss_wave(index), "wave %d is not a boss wave" % index)


func test_out_of_range_waves_are_clamped() -> void:
	equal(WaveData.get_wave(0)["index"], 1, "wave 0 clamps to the first wave")
	equal(WaveData.get_wave(99)["index"], WaveData.TOTAL, "past the end clamps to the last wave")
	check(WaveData.prepare_time(1) > WaveData.prepare_time(2), "the first countdown is longer")
