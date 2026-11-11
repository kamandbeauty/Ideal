extends RefCounted
## Fire cadence, ammunition and reload of the weapon logic.


func _fire_for(state: WeaponState, seconds: float, rate: float) -> int:
	var fired: int = 0
	var ticks: int = int(round(seconds * rate))
	for index: int in ticks:
		state.step(1.0 / rate)
		while state.try_fire():
			fired += 1
	return fired


func run(t: TestContext) -> void:
	var shipped: WeaponData = load("res://resources/weapons/twin_hmg.tres")
	t.check(shipped != null, "twin_hmg.tres loads as WeaponData")
	t.check(shipped.damage > 0.0 and shipped.fire_interval > 0.0 and shipped.magazine_size > 0, "shipped weapon numbers are positive")

	var data: WeaponData = shipped.duplicate()
	data.magazine_size = 100000
	data.fire_interval = 0.085
	var expected: float = 10.0 / data.fire_interval
	for rate: float in [30.0, 60.0, 120.0]:
		var fired: int = _fire_for(WeaponState.new(data), 10.0, rate)
		t.check(absf(float(fired) - expected) <= 2.0, "rate of fire is exact at %d Hz (%d shots, expected %.1f)" % [int(rate), fired, expected])

	# A long pause must not bank shots.
	var state := WeaponState.new(data)
	for index: int in 600:
		state.step(1.0 / 60.0)
	var burst: int = 0
	while state.try_fire():
		burst += 1
	t.equal(burst, 1, "no burst is released after holding fire off")

	# Magazine and reload.
	data = shipped.duplicate()
	data.magazine_size = 5
	data.reload_time = 1.0
	data.fire_interval = 0.05
	state = WeaponState.new(data)
	var events: Array[String] = []
	state.reload_started.connect(func(_duration: float) -> void: events.append("start"))
	state.reload_finished.connect(func() -> void: events.append("finish"))
	t.equal(state.ammo, 5, "a new weapon starts with a full magazine")
	t.check(not state.start_reload(), "reloading a full magazine is refused")
	var fired: int = _fire_for(state, 0.5, 60.0)
	t.equal(fired, 5, "exactly one magazine is fired")
	t.equal(state.ammo, 0, "the magazine is empty")
	t.check(state.reloading, "an empty magazine reloads automatically")
	t.equal(events, ["start"], "reload_started is emitted once")
	t.check(not state.try_fire(), "the weapon cannot fire while reloading")
	t.check(state.reload_progress() < 1.0, "reload progress is under 1 during the reload")
	var before: float = state.reload_progress()
	for index: int in 12:
		state.step(1.0 / 60.0)
	t.check(state.reloading, "the reload is still running part-way through")
	t.near(state.reload_progress() - before, 0.2, 0.02, "reload progress tracks time")
	for index: int in 60:
		state.step(1.0 / 60.0)
	t.check(not state.reloading, "the reload completes after reload_time")
	t.equal(state.ammo, 5, "the reload refills the magazine")
	t.equal(events, ["start", "finish"], "reload_finished is emitted once")
	t.near(state.reload_progress(), 1.0, 0.0001, "reload progress is 1 when idle")

	# Manual reload with rounds left.
	state.step(1.0)
	t.check(state.try_fire(), "the weapon fires again after the reload")
	t.check(state.start_reload(), "a partial magazine can be reloaded by hand")
	t.check(not state.start_reload(), "a second reload request is ignored while reloading")

	# No automatic reload when the data says so.
	data.auto_reload = false
	state = WeaponState.new(data)
	_fire_for(state, 0.5, 60.0)
	t.check(not state.reloading and state.ammo == 0, "auto_reload off leaves the weapon empty")

	# A limited supply: the launcher's one round and the rockets on the gunner's back.
	var launcher: WeaponData = (load("res://resources/weapons/rpg_launcher.tres") as WeaponData).duplicate()
	launcher.reserve = 2
	launcher.reserve_max = 4
	launcher.reload_time = 1.0
	var tube := WeaponState.new(launcher)
	t.equal(tube.ammo, 1, "the launcher starts loaded")
	t.equal(tube.rounds_left(), 3, "loaded and spare rounds are counted together")
	t.check(not tube.is_spent(), "a loaded launcher is not spent")
	t.check(tube.try_fire(), "the loaded round fires")
	t.check(tube.reloading, "an empty launcher reloads itself while rounds remain")
	t.check(not tube.try_fire(), "nothing fires during the reload")
	for index: int in 61:
		tube.step(1.0 / 60.0)
	t.check(not tube.reloading and tube.ammo == 1, "the reload seats one round")
	t.equal(tube.reserve, 1, "the round came out of the reserve")
	tube.step(1.0)
	t.check(tube.try_fire(), "the second round fires")
	for index: int in 61:
		tube.step(1.0 / 60.0)
	tube.step(1.0)
	t.check(tube.try_fire(), "the last round fires")
	t.check(tube.is_spent(), "with nothing loaded and nothing spare the launcher is spent")
	t.check(not tube.reloading and not tube.start_reload(), "there is nothing to reload from")
	t.equal(tube.rounds_left(), 0, "no rounds are left")
	t.equal(tube.add_reserve(3), 3, "resupply adds spare rounds")
	t.check(tube.reloading, "a resupplied empty launcher starts loading at once")
	t.equal(tube.add_reserve(5), 1, "resupply stops at the carrying limit")
	t.equal(tube.reserve, 4, "the reserve is at its limit")
	t.equal(tube.add_reserve(0), 0, "adding nothing adds nothing")
	# A partial reload takes only what the magazine needs and what the reserve has.
	var clip: WeaponData = shipped.duplicate()
	clip.magazine_size = 10
	clip.reserve = 4
	clip.reserve_max = 20
	clip.reload_time = 0.5
	var limited := WeaponState.new(clip)
	for index: int in 7:
		limited.step(1.0)
		limited.try_fire()
	t.equal(limited.ammo, 3, "seven rounds are gone")
	limited.start_reload()
	limited.step(1.0)
	t.equal(limited.ammo, 7, "the reload adds only the four spare rounds")
	t.equal(limited.reserve, 0, "and empties the reserve")
	# The belt-fed gun never runs out.
	var belt := WeaponState.new(shipped)
	t.equal(belt.rounds_left(), -1, "an unlimited supply reports no count")
	t.equal(belt.add_reserve(10), 0, "an unlimited supply takes no resupply")
	t.check(not belt.is_spent(), "an unlimited supply is never spent")
