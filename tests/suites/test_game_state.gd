extends TestCase
## Economy, core integrity and the wave phase machine.


func test_starting_values() -> void:
	var state := GameState.new()
	equal(state.gold, GameState.STARTING_GOLD, "starting gold")
	equal(state.core, GameState.CORE_MAX, "starting core integrity")
	equal(state.wave, 0, "no wave has started")
	equal(state.phase, GameState.Phase.PREPARE, "a run opens in the build phase")
	check(not state.is_finished(), "a new run is not over")
	equal(state.snapshot()["total_waves"], WaveData.TOTAL, "snapshot reports the wave count")


func test_spending_and_earning() -> void:
	var state := GameState.new()
	var seen: Array = []
	state.gold_changed.connect(func(gold: int) -> void: seen.append(gold))

	check(state.spend(100), "an affordable tower is bought")
	equal(state.gold, GameState.STARTING_GOLD - 100, "gold is deducted")
	equal(seen.size(), 1, "a purchase announces the new balance")
	check(not state.spend(1_000_000), "an unaffordable purchase is refused")
	equal(state.gold, GameState.STARTING_GOLD - 100, "a refused purchase changes nothing")
	check(not state.spend(-5), "negative costs are refused")

	state.earn(40)
	equal(state.gold, GameState.STARTING_GOLD - 60, "rewards are added")
	state.earn(0)
	state.earn(-10)
	equal(state.gold, GameState.STARTING_GOLD - 60, "non-positive rewards are ignored")


func test_core_damage_ends_a_run() -> void:
	var state := GameState.new()
	var results: Array = []
	state.finished.connect(func(victory: bool) -> void: results.append(victory))

	state.damage_core(5)
	equal(state.core, GameState.CORE_MAX - 5, "the core takes damage")
	state.damage_core(GameState.CORE_MAX)
	equal(state.core, 0, "the core cannot go negative")
	check(state.is_finished(), "losing the core ends the run")
	equal(results.size(), 1, "the end of a run is announced once")
	equal(results[0], false, "an empty core is a defeat")

	state.damage_core(3)
	equal(results.size(), 1, "a finished run stays finished")


func test_wave_progression() -> void:
	var state := GameState.new()
	equal(state.begin_wave(), 1, "the first wave is number one")
	equal(state.phase, GameState.Phase.WAVE, "starting a wave changes the phase")
	state.begin_wave()
	equal(state.wave, 1, "a running wave cannot be started twice")
	state.complete_wave()
	equal(state.completed_waves, 1, "the completed wave is recorded")
	equal(state.phase, GameState.Phase.PREPARE, "the build phase returns")
	state.begin_wave()
	equal(state.wave, 2, "the next wave follows")
	state.complete_wave()
	equal(state.completed_waves, 2, "two waves are behind us")


func test_a_full_run_ends_in_victory() -> void:
	var state := GameState.new()
	var results: Array = []
	state.finished.connect(func(victory: bool) -> void: results.append(victory))

	for index in range(1, WaveData.TOTAL + 1):
		equal(state.begin_wave(), index, "wave %d starts" % index)
		state.complete_wave()

	check(state.is_finished(), "ten cleared waves end the run")
	equal(state.completed_waves, WaveData.TOTAL, "every wave counts")
	equal(results.size(), 1, "victory is announced once")
	equal(results[0], true, "clearing the last wave is a victory")
	state.begin_wave()
	equal(state.wave, WaveData.TOTAL, "no wave starts after the run is over")
