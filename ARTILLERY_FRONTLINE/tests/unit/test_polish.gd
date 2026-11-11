extends RefCounted
## The parts of the sound and effects polish that need no level: the quality
## tiers, the rules of the mixer, the sound clips the code asks for by name,
## and the pooled marks and casings.


func _scripts(folder: String, found: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".gd"):
			found.append(folder + "/" + file_name)
	for sub: String in DirAccess.get_directories_at(folder):
		_scripts(folder + "/" + sub, found)


func run(t: TestContext) -> void:
	_tiers(t)
	_clips(t)
	_voices(t)
	_loops_and_buses(t)
	await _loop_fade(t)
	await _marks(t)
	await _casings(t)
	_flare(t)


func _tiers(t: TestContext) -> void:
	var keys: Array[String] = ["scale", "shadows", "shadow_distance", "msaa", "glow", "normal_maps", "particles", "corpses", "fires", "ash",
		"lights", "detail"]
	var missing: Array[String] = []
	for tier: String in Graphics.TIERS:
		for key: String in keys:
			if not Graphics.PROFILES[tier].has(key):
				missing.append(tier + "." + key)
	t.check(missing.is_empty(), "every quality tier sets every switch (%s)" % str(missing))
	var low: Dictionary = Graphics.PROFILES["low"]
	var medium: Dictionary = Graphics.PROFILES["medium"]
	var high: Dictionary = Graphics.PROFILES["high"]
	t.check(not low.lights and not low.detail and not low.ash and not low.shadows and not low.glow,
		"the lowest tier pays for no flash lights, no particle dressing, no ash, no shadows and no glow")
	t.check(medium.lights and medium.detail and medium.ash and high.lights and high.detail and high.ash,
		"the middle and top tiers keep the flash lights, the dressing and the ash")
	t.check(low.scale < medium.scale and medium.scale < high.scale, "each tier renders more pixels than the one below")
	t.check(low.particles < medium.particles and medium.particles < high.particles, "and more particles")
	t.check(low.corpses < medium.corpses and medium.corpses < high.corpses, "and keeps more bodies on the ground")
	t.equal(Graphics.resolve_tier("low"), "low", "a chosen tier is used as it is")
	t.check(Graphics.TIERS.has(Graphics.resolve_tier("auto")), "\"auto\" resolves to a real tier")
	_governor(t)


## Runs the governor against a pretend phone for `seconds`; `cost` gives the frame time in ms for (tier, render scale).
func _play(seconds: float, cost: Callable) -> void:
	var left: float = seconds
	while left > 0.0:
		var frame_ms: float = cost.call(Graphics.tier, Graphics.render_scale)
		var delta: float = minf(frame_ms / 1000.0, 0.1)
		Graphics.observe(frame_ms, delta)
		left -= delta


func _fresh(tier: String) -> void:
	Graphics.auto_tier = ""
	Graphics.forget()
	Graphics.apply_tier(tier)


## With quality on "auto": the cheapest thing first, nothing that buys no frames, and no swinging back and forth.
func _governor(t: TestContext) -> void:
	var shipped: GovernorSettings = Graphics.rules
	var tier_before: String = Graphics.tier
	var auto_before: String = Graphics.auto_tier
	var target_before: float = Graphics.monitor.target_fps
	t.check(shipped != null and ResourceLoader.exists(Graphics.RULES_PATH) and load(Graphics.RULES_PATH) is GovernorSettings,
		"the governor's numbers come from a resource file")
	t.check(shipped.scale_floor < float(Graphics.PROFILES["low"].scale) and shipped.scale_step > 0.0 and shipped.slow_ratio > shipped.fast_ratio
		and shipped.fast_window >= shipped.slow_window and shipped.min_gain > 0.0 and Graphics.TIERS.has(shipped.lowest_tier),
		"and the shipped numbers make sense together")
	# Everything below runs on the numbers written in the script, so tuning the file after a device test cannot break it.
	var rules := GovernorSettings.new()
	Graphics.rules = rules
	Graphics.monitor.rules = rules
	Graphics.monitor.target_fps = 60.0
	t.near(Graphics.monitor.slow_below_fps(), 49.2, 0.1, "with a 60 fps target a frame is slow below 49 fps")
	t.near(FrameMonitor.effective_target(60.0, 50.0), 50.0, 0.001, "a 50 Hz display lowers the target to 50")
	t.near(FrameMonitor.effective_target(60.0, 120.0), 60.0, 0.001, "a 120 Hz display does not raise it")
	t.near(FrameMonitor.effective_target(60.0, -1.0), 60.0, 0.001, "an unknown refresh rate leaves it alone")
	var medium: float = Graphics.PROFILES["medium"].scale
	var low: float = Graphics.PROFILES["low"].scale

	# 1. A healthy phone, with one bad frame.
	_fresh("medium")
	Graphics.observe(250.0, 0.1)
	_play(60.0, func(_tier: String, _scale: float) -> float: return 16.6)
	t.check(Graphics.scale_changes == 0 and Graphics.tier_changes == 0 and is_equal_approx(Graphics.render_scale, medium),
		"one slow frame and a minute of good ones change nothing")

	# 2. A phone short of fill rate: the frame gets shorter with the resolution.
	_fresh("medium")
	var fill := func(_tier: String, scale: float) -> float: return 8.0 + 22.0 * scale * scale
	_play(2.6, fill)
	t.near(Graphics.render_scale, medium - rules.scale_step, 0.0001, "two seconds of slow frames lower the render resolution one step")
	_play(120.0, fill)
	var rest: float = Graphics.render_scale
	t.check(rest < medium and rest > rules.scale_floor and not Graphics.monitor.is_slow(fill.call("medium", rest)),
		"it stops at the first resolution that is no longer slow (%.2f)" % rest)
	t.equal(Graphics.tier, "medium", "and the tier has not moved")
	var changes: int = Graphics.scale_changes
	_play(600.0, fill)
	t.check(Graphics.scale_changes == changes and is_equal_approx(Graphics.render_scale, rest), "ten more minutes change nothing")

	# 3. A phone on the edge: one step down is fast, the step back up is slow again.
	_fresh("medium")
	var edge := func(_tier: String, scale: float) -> float: return 24.0 if scale > 0.8 else 16.0
	_play(600.0, edge)
	t.near(Graphics.render_scale, medium - rules.scale_step, 0.0001, "a phone on the edge settles one step down")
	t.equal(Graphics.scale_changes, 3, "down, one try at coming back, down again: three changes in ten minutes, not a swing every few seconds")
	t.near(Graphics.scale_ceiling, medium - rules.scale_step, 0.0001, "the step up that was regretted has set the ceiling")

	# 4. A phone held back by its processor: nothing the governor can do shortens a frame.
	_fresh("medium")
	var stuck := func(_tier: String, _scale: float) -> float: return 25.0
	_play(17.0, stuck)
	t.near(Graphics.render_scale, rules.scale_floor, 0.0001, "frames stay slow, so the resolution goes down to its floor")
	t.equal(Graphics.tier, "medium", "and the tier has still not moved")
	_play(2.0, stuck)
	t.check(Graphics.scale_useless and is_equal_approx(Graphics.render_scale, medium), "all the way down bought nothing, so the resolution is given back")
	_play(7.0, stuck)
	t.equal(Graphics.tier, "low", "still slow with nothing left to try, one tier is given up")
	t.near(Graphics.render_scale, low, 0.0001, "at its own resolution")
	_play(7.0, stuck)
	t.equal(Graphics.tier, "medium", "that bought nothing either, so the tier is taken back")
	t.check(Graphics.tier_locked and Graphics.tier_changes == 2, "and tiers are settled for the session")
	t.equal(Graphics.resolve_tier("auto"), "medium", "\"auto\" means that tier again")
	var settled: Array = [Graphics.scale_changes, Graphics.tier_changes]
	_play(600.0, stuck)
	t.check([Graphics.scale_changes, Graphics.tier_changes] == settled and is_equal_approx(Graphics.render_scale, medium),
		"ten more slow minutes change nothing: the picture is not made worse for no gain")

	# 5. A phone the lower tier does help.
	_fresh("medium")
	var helped := func(tier: String, _scale: float) -> float: return 25.0 if tier == "medium" else 15.0
	_play(60.0, helped)
	t.equal(Graphics.tier, "low", "where giving up a tier does shorten the frames, the lower tier is kept")
	t.check(Graphics.tier_changes == 1 and not Graphics.tier_locked, "with a single change")
	t.equal(Graphics.resolve_tier("auto"), "low", "and \"auto\" means that tier for the rest of the session")
	t.equal(Graphics.resolve_tier("high"), "high", "a tier the player chooses is still the player's to choose")
	_play(600.0, helped)
	t.check(Graphics.tier == "low" and Graphics.tier_changes == 1, "it does not come back up: a phone that struggled once will again")

	# 6. The file can forbid the lowest tier.
	_fresh("medium")
	rules.lowest_tier = "medium"
	_play(120.0, stuck)
	t.check(Graphics.tier == "medium" and Graphics.tier_changes == 0 and Graphics.tier_locked, "with the lowest tier set to medium, medium is never given up")
	rules.lowest_tier = "low"

	# 7. Fast frames bring the resolution back.
	_fresh("medium")
	Graphics.render_scale = rules.scale_floor
	_play(120.0, func(_tier: String, _scale: float) -> float: return 12.0)
	t.near(Graphics.render_scale, medium, 0.0001, "fast frames bring the resolution back up to the tier's own")
	t.equal(Graphics.tier, "medium", "without touching the tier")

	# Changing some other setting must not undo what the governor has learnt.
	Profile.persist = false
	_fresh("medium")
	_play(60.0, helped)
	Profile.set_setting("quality", "auto")
	Graphics.apply_preference()
	Graphics.render_scale = 0.61
	Profile.set_setting("show_fps", not bool(Profile.setting("show_fps")))
	t.near(Graphics.render_scale, 0.61, 0.0001, "changing another setting leaves the render resolution alone")
	t.equal(Graphics.tier, "low", "and the tier")
	Profile.set_setting("quality", "high")
	t.equal(Graphics.tier, "high", "choosing a tier applies it at once")
	t.near(Graphics.render_scale, float(Graphics.PROFILES["high"].scale), 0.0001, "at its full resolution")
	t.check(not Graphics.governing(), "and the governor leaves a tier the player chose alone")
	Profile.set_setting("quality", "auto")
	t.check(Graphics.governing(), "on \"auto\" it is at work")
	rules.enabled = false
	t.check(not Graphics.governing(), "unless the file switches it off")
	rules.enabled = true
	Graphics.governor = false
	t.check(not Graphics.governing(), "or the screenshot run does")
	Graphics.governor = true
	Graphics.rules = shipped
	Graphics.monitor.rules = shipped
	Graphics.monitor.target_fps = target_before
	Graphics.auto_tier = auto_before
	Profile.reset()
	Graphics.apply_preference()
	Graphics.forget()
	if Graphics.tier != tier_before:
		Graphics.apply_tier(tier_before)


## Every sound the scripts ask for by name must exist: a missing clip is silent, not an error.
func _clips(t: TestContext) -> void:
	var scripts: Array[String] = []
	_scripts("res://scripts", scripts)
	# Any quoted lower-case word on a line that calls Sound is a clip name (bus names are capitalised).
	var quoted := RegEx.new()
	quoted.compile("\"([a-z][a-z0-9_]*)\"")
	var variants := RegEx.new()
	variants.compile("play_variant_at\\(\\s*\"([a-z0-9_]+)\"\\s*,\\s*(\\d+)")
	# Buttons are handed the name of their sound as their last argument.
	var handed := RegEx.new()
	handed.compile("\"(ui_[a-z0-9_]+)\"")
	var asked: Dictionary = {}
	for path: String in scripts:
		if path.ends_with("audio_manager.gd"):
			continue
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if line.contains("Sound."):
				for found: RegExMatch in variants.search_all(line):
					for index: int in int(found.get_string(2)):
						asked["%s_%d" % [found.get_string(1), index + 1]] = path.get_file()
				for found: RegExMatch in quoted.search_all(line):
					var name: String = found.get_string(1)
					# The stem of a numbered family ("gate_hit") is played through its variants.
					if not Sound.has_clip(name + "_1"):
						asked[name] = path.get_file()
			elif line.contains("UITheme.button(") or line.contains("sound: String ="):
				for found: RegExMatch in handed.search_all(line):
					asked[found.get_string(1)] = path.get_file()
	var silent: Array[String] = []
	for name: String in asked:
		if not Sound.has_clip(name):
			silent.append("%s (%s)" % [name, asked[name]])
	t.check(silent.is_empty(), "every sound a script asks for exists (%s)" % str(silent))
	t.check(asked.size() >= 30, "the scan found the sounds the scripts play (%d)" % asked.size())
	for name: String in ["ui_toggle", "ui_start", "ui_back", "body_fall", "hmg_tail", "victory", "defeat"]:
		t.check(Sound.has_clip(name), "the %s clip is shipped" % name)
		t.check(asked.has(name), "and something plays it")
	var unknown: Array[String] = []
	for name: String in Sound.MIN_GAP_MS:
		if not Sound.CLIPS.has(name):
			unknown.append(name)
	for name: String in Sound.RANK:
		if not Sound.CLIPS.has(name):
			unknown.append(name)
	t.check(unknown.is_empty(), "throttles and ranks only name real clips (%s)" % str(unknown))


func _voices(t: TestContext) -> void:
	# A silent voice is always taken first.
	var busy := PackedByteArray([1, 1, 0, 1])
	var ranks := PackedInt32Array([0, 1, 3, 2])
	var since := PackedInt64Array([10, 20, 30, 40])
	t.equal(Sound.choose_voice(busy, ranks, since, 0), 2, "a new sound takes a silent voice when there is one")
	# All busy: the least important goes, and among equals the one that has sounded longest.
	busy = PackedByteArray([1, 1, 1, 1])
	ranks = PackedInt32Array([2, 0, 1, 0])
	since = PackedInt64Array([5, 40, 10, 30])
	t.equal(Sound.choose_voice(busy, ranks, since, 1), 3, "otherwise it takes the oldest of the least important sounds")
	t.equal(Sound.choose_voice(busy, ranks, since, 0), 3, "a bullet strike may replace another bullet strike")
	ranks = PackedInt32Array([2, 3, 2, 3])
	t.equal(Sound.choose_voice(busy, ranks, since, 1), -1, "nothing ordinary cuts off a blast or an alarm")
	t.equal(Sound.choose_voice(busy, ranks, since, 2), 0, "a blast may replace an older blast")
	t.equal(Sound.choose_voice(busy, ranks, since, 3), 0, "an alarm takes the least important voice, not another alarm")
	t.equal(Sound.choose_voice(PackedByteArray(), PackedInt32Array(), PackedInt64Array(), 3), -1, "no voices, no sound")
	# What matters more than what.
	t.check(Sound.rank_of("impact") < Sound.rank_of("hmg_shot"), "bullet strikes give way to the gun")
	t.check(Sound.rank_of("zombie_groan_1") < Sound.rank_of("zombie_death_1"), "groans give way to death cries")
	t.check(Sound.rank_of("hmg_shot") < Sound.rank_of("explosion"), "the gun does not cut off a blast")
	t.check(Sound.rank_of("explosion") < Sound.rank_of("alarm"), "nothing cuts off the alarm")
	for name: String in ["boss_roar", "boss_death", "gate_break", "wall_break", "wave_horn", "victory", "defeat"]:
		t.check(Sound.rank_of(name) > Sound.rank_of("hmg_shot"), "%s outranks the gun" % name)
	t.equal(Sound.rank_of("click"), 1, "a clip without a rank of its own is ordinary")
	# The same clip cannot be started twice inside its gap.
	Sound.last_start.erase("body_fall")
	var first: bool = Sound.play_at("body_fall", Vector3.ZERO)
	var second: bool = Sound.play_at("body_fall", Vector3.ZERO)
	t.check(first and not second, "a throttled clip does not start twice in the same instant")
	t.check(not Sound.play("no_such_clip"), "an unknown clip is refused")


func _loops_and_buses(t: TestContext) -> void:
	# The importer stores clips compressed; a loop measured in bytes ended two fifths of the way through the theme.
	var wind: AudioStreamWAV = Sound.clips["wind"]
	var theme: AudioStreamWAV = Sound.clips["music_theme"]
	t.equal(Sound.frames_of(wind), 8 * 24000, "the wind bed is measured as its full eight seconds")
	t.equal(Sound.frames_of(theme), 48 * 24000, "the theme is measured as its full forty-eight seconds")
	var was_looping: bool = Sound.is_looping("wind")
	Sound.start_loop("wind", "Effects", -19.0)
	var player: AudioStreamPlayer = Sound.loops["wind"]
	var stream: AudioStreamWAV = player.stream
	t.equal(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "a bed loops forward")
	t.equal(stream.loop_begin, 0, "from its first frame")
	t.equal(stream.loop_end, 8 * 24000, "to its last")
	t.check(wind.loop_mode == AudioStreamWAV.LOOP_DISABLED, "the shared clip itself is left as a one-shot")
	if not was_looping:
		Sound.stop_loop("wind")
		t.check(not Sound.is_looping("wind"), "a stopped bed is gone")
	t.check(AudioServer.get_bus_index("Effects") > 0 and AudioServer.get_bus_index("Music") > 0, "effects and music have a bus each")
	t.equal(String(AudioServer.get_bus_send(AudioServer.get_bus_index("Effects"))), "Master", "effects feed the master bus")
	var limiter: AudioEffectHardLimiter = null
	var limiters: int = 0
	var place: int = -1
	for index: int in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, index) is AudioEffectHardLimiter:
			limiter = AudioServer.get_bus_effect(0, index)
			place = index
			limiters += 1
	t.equal(limiters, 1, "the master bus carries one limiter")
	t.check(limiter != null and limiter.ceiling_db <= -0.5 and limiter.ceiling_db >= -3.0,
		"which stops the mix just short of full scale")
	t.check(place >= 0 and AudioServer.is_bus_effect_enabled(0, place), "and is switched on")
	# Muting through the settings.
	Profile.persist = false
	Profile.set_setting("music_volume", 0.0)
	t.check(AudioServer.is_bus_mute(Sound.music_bus), "music volume zero mutes the music bus")
	t.check(not AudioServer.is_bus_mute(Sound.sfx_bus), "and leaves the effects (and the wind) alone")
	Profile.set_setting("music_volume", 0.5)
	t.near(AudioServer.get_bus_volume_db(Sound.music_bus), linear_to_db(0.5), 0.01, "half volume is six decibels down")
	Profile.reset()


## A bed comes up from silence instead of starting on a step.
func _loop_fade(t: TestContext) -> void:
	var enabled: bool = Sound.playback_enabled
	Sound.playback_enabled = true
	Sound.start_loop("ui_start", "Effects", -19.0, 0.25)
	var player: AudioStreamPlayer = Sound.loops["ui_start"]
	t.check(player.playing, "a bed that is started plays")
	t.near(player.volume_db, Sound.SILENT_DB, 0.01, "from silence")
	await t.tree.create_timer(0.12).timeout
	t.check(player.volume_db > Sound.SILENT_DB + 6.0 and player.volume_db <= -18.99, "rising (%.1f dB part of the way through its fade)" % player.volume_db)
	await t.tree.create_timer(0.25).timeout
	t.near(player.volume_db, -19.0, 0.01, "to the level it was given")
	Sound.stop_loop("ui_start")
	await t.frames(2)
	t.check(not Sound.is_looping("ui_start") and not is_instance_valid(player), "stopping it frees its player, and the fade with it")
	Sound.start_loop("ui_back", "Effects", -12.0, 0.0)
	t.near((Sound.loops["ui_back"] as AudioStreamPlayer).volume_db, -12.0, 0.01, "a bed asked for without a fade starts at its level")
	Sound.stop_loop("ui_back")
	Sound.playback_enabled = enabled
	await t.frames(1)


func _marks(t: TestContext) -> void:
	var marks := MarkPool.new()
	t.tree.root.add_child(marks)
	await t.frames(1)
	var nodes: int = marks.get_child_count()
	t.equal(nodes, MarkPool.KINDS.size(), "one batch per kind of mark")
	var total: int = 0
	for kind: String in MarkPool.KINDS:
		total += int(MarkPool.KINDS[kind].count)
	t.equal(marks.capacity(), total, "the pool knows how many marks it can show")
	t.check(not marks.is_processing(), "an empty pool does not run")
	# On the ground. (The pool keeps its own record of every mark: a renderer cannot be asked what it was told.)
	t.equal((marks.meshes["scar"] as MultiMesh).instance_count, int(MarkPool.KINDS["scar"].count), "a batch is as big as its kind allows")
	t.check(marks.shown("scar", 0).origin.y < -100.0, "an unused place is hidden")
	t.equal(marks.mark("scar", Vector3(1.0, 0.0, 2.0), Vector3.UP), 0, "the first mark takes the first place")
	t.equal(marks.mark("scar", Vector3(3.0, 0.0, 2.0), Vector3.UP), 1, "the next one the next")
	var floor_mark: Transform3D = marks.shown("scar", 0)
	t.near(floor_mark.origin.x, 1.0, 0.001, "a mark lies where the round struck")
	t.check(floor_mark.origin.y > 0.0 and floor_mark.origin.y < 0.06, "just clear of the surface (%.3f m)" % floor_mark.origin.y)
	t.check(floor_mark.basis.y.normalized().dot(Vector3.UP) > 0.999, "a floor mark faces up")
	var width: float = floor_mark.basis.x.length()
	t.check(width >= MarkPool.KINDS["scar"].size.x - 0.001 and width <= MarkPool.KINDS["scar"].size.y + 0.001,
		"a scar is as wide as a heavy round makes it (%.2f m)" % width)
	# On a wall.
	var slot: int = marks.mark("scar", Vector3(5.0, 2.0, -3.0), Vector3(1.0, 0.0, 0.0))
	var wall_mark: Transform3D = marks.shown("scar", slot)
	t.check(wall_mark.basis.y.normalized().dot(Vector3.RIGHT) > 0.999, "a wall mark faces out of the wall")
	t.check(absf(wall_mark.basis.x.normalized().dot(Vector3.RIGHT)) < 0.001 and absf(wall_mark.basis.z.normalized().dot(Vector3.RIGHT)) < 0.001,
		"and lies flat against it")
	t.check(wall_mark.origin.x > 5.0 and wall_mark.origin.x < 5.06, "just clear of the wall")
	t.equal(marks.mark("scar", Vector3.ZERO, Vector3.ZERO), 3, "a strike with no usable normal still leaves a mark")
	t.equal(marks.mark("no_such_kind", Vector3.ZERO), -1, "an unknown kind leaves nothing")
	# More marks than places: the oldest is replaced, nothing is created.
	var count: int = int(MarkPool.KINDS["scar"].count)
	var last: int = -1
	for index: int in count:
		last = marks.mark("scar", Vector3(float(index), 0.0, 0.0))
	t.equal(last, 3, "past its capacity the pool starts again from the oldest mark")
	t.equal(int(marks.placed["scar"]), count + 4, "every mark is counted")
	t.equal(marks.get_child_count(), nodes, "and no node is created for any of them")
	# Blood spreads, then rests.
	var pool: int = marks.mark("blood", Vector3(0.0, 0.0, -5.0), Vector3.UP, 1.0)
	t.check(marks.is_processing(), "fresh blood is still spreading")
	var early: float = marks.shown("blood", pool).basis.x.length()
	marks._process(0.4)
	var later: float = marks.shown("blood", pool).basis.x.length()
	marks._process(2.0)
	var settled: float = marks.shown("blood", pool).basis.x.length()
	t.check(early < later and later < settled, "it grows (%.2f, %.2f, %.2f m)" % [early, later, settled])
	t.check(settled >= MarkPool.KINDS["blood"].size.x - 0.001 and settled <= MarkPool.KINDS["blood"].size.y + 0.001,
		"to the size of a pool under a body")
	t.check(not marks.is_processing() and marks.spreading.is_empty(), "then the pool stops running")
	var bigger: int = marks.mark("blood", Vector3(4.0, 0.0, -5.0), Vector3.UP, 2.0)
	marks._process(3.0)
	t.check(marks.shown("blood", bigger).basis.x.length() > MarkPool.KINDS["blood"].size.y,
		"a bigger body leaves a bigger pool")
	t.near(marks.shown("blood", bigger).basis.y.length(), 1.0, 0.001, "spreading never thickens a mark")
	marks.clear()
	t.check(marks.shown("scar", 0).origin.y < -100.0 and marks.shown("blood", pool).origin.y < -100.0,
		"clearing hides every mark")
	t.equal(marks.mark("scar", Vector3.ZERO), 0, "and starts again from the first place")
	marks.queue_free()
	await t.frames(1)


func _casings(t: TestContext) -> void:
	var casings := CasingPool.new()
	t.tree.root.add_child(casings)
	await t.frames(1)
	t.check(not casings.is_processing() and casings.flying == 0, "with nothing in the air the casing pool sleeps")
	t.equal(casings.multimesh.instance_count, CasingPool.COUNT, "the brass is one batch of fixed size")
	casings.eject(Vector3(0.0, 2.0, 0.0), Vector3(2.0, 1.0, 0.0))
	t.check(casings.is_processing() and casings.flying == 1 and casings.ejected == 1, "a spent case wakes it")
	casings._process(0.1)
	var place: Vector3 = casings.positions[0]
	t.near(place.x, 0.2, 0.001, "the case flies the way it was thrown")
	t.check(place.y > 2.0 and place.y < 2.1, "rising at first, with gravity on it (%.3f m)" % place.y)
	var turned: float = casings.angles[0]
	casings._process(0.1)
	t.check(absf(casings.angles[0] - turned) > 1.0, "and tumbling (%.1f rad in a tenth of a second)" % absf(casings.angles[0] - turned))
	t.near(casings.axes[0].length(), 1.0, 0.001, "about an axis of its own")
	casings._process(0.25)
	t.check(casings.positions[0].y < 2.0, "then it falls")
	casings._process(0.25)
	t.check(casings.flying == 0 and not casings.is_processing(), "after %.1f s it is gone and the pool sleeps again" % CasingPool.LIFE)
	t.equal(casings.alive[0], 0, "its place is free")
	for index: int in CasingPool.COUNT + 7:
		casings.eject(Vector3.ZERO, Vector3.RIGHT)
	t.equal(casings.flying, CasingPool.COUNT, "a long burst never has more cases in the air than the pool holds")
	t.equal(casings.ejected, CasingPool.COUNT + 8, "though every one is counted")
	casings.clear()
	t.check(casings.flying == 0 and not casings.is_processing(), "clearing empties the air")
	casings.queue_free()
	await t.frames(1)


func _flare(t: TestContext) -> void:
	var flare: Texture2D = EffectPool.flare(6)
	var image: Image = flare.get_image()
	var size: int = image.get_width()
	t.check(image.get_pixel(size / 2, size / 2).a > 0.9, "the flash texture is hot at its heart")
	t.check(image.get_pixel(0, 0).a < 0.01 and image.get_pixel(size - 1, size - 1).a < 0.01, "and empty at its corners")
	var lit: int = 0
	var rim: int = 0
	for step: int in 64:
		var angle: float = TAU * float(step) / 64.0
		var at := Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.3
		# (0.3 of the texture is 0.6 of the way from its heart to its edge: outside the heart, among the rays.)
		rim += 1
		if image.get_pixel(int(at.x * float(size)), int(at.y * float(size))).a > 0.12:
			lit += 1
	t.check(lit > 4 and lit < rim - 4, "between them it is rays, not a disc (%d of %d lit)" % [lit, rim])
	t.check(EffectPool.flare(6) == flare, "the texture is built once")
	t.check(EffectPool.flare(8) != flare, "a flash with more rays is its own texture")
