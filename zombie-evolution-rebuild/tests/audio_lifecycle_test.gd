extends SceneTree

const AudioProbe = preload("res://ci/audio_probe.gd")
const SoundScript = preload("res://scripts/level/sound_effects.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func load_scene(path: String) -> void:
	var result := change_scene_to_file(path)
	check(result == OK, "scene change requested: " + path)
	await process_frame
	await process_frame

func run_tests() -> void:
	check(OS.has_environment("CI_SOUND_DIAGNOSTICS"), "playback lifetime instrumentation enabled")
	await load_scene("res://scenes/launcher.tscn")
	var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for restart in range(3):
		await load_scene("res://scenes/level/sky_bridge.tscn")
		var level = current_scene
		level.set_physics_process(false)
		var sound = level.sound
		var sound_ref: WeakRef = weakref(sound)
		var level_ref: WeakRef = weakref(level)
		await physics_frame
		var target = level.enemies[0]
		target.position = Vector3(0, 0.05, 7)
		await physics_frame
		var health: float = target.health
		level.shoot_at(level.hero, target.global_position + Vector3(0, 1.2, 0), 1.0)
		check(target.health < health, "zombie damage uses real shot and impact effect")
		check(sound.voices.any(func(voice): return voice.playing and voice.stream == SoundScript.EFFECTS["impact"]), "damage starts impact playback")
		var kills: int = level.kills
		level.shoot_at(level.hero, target.global_position + Vector3(0, 1.2, 0), 10000.0)
		check(level.kills == kills + 1, "zombie death follows real shot")
		check(sound.voices.any(func(voice): return voice.playing and voice.stream == SoundScript.EFFECTS["impact"]), "fatal hit starts impact playback")
		for i in range(100):
			sound.play_effect("rifle")
		check(sound.voices.size() == SoundScript.VOICE_COUNT and sound.get_child_count() == SoundScript.VOICE_COUNT, "repeated shots keep a bounded player pool")
		for i in range(6):
			sound.play_effect("impact")
		var impacts := 0
		for voice in sound.voices:
			if voice.playing and voice.stream == SoundScript.EFFECTS["impact"]:
				impacts += 1
		check(impacts >= 6, "multiple impact sounds overlap")
		check(not AudioProbe.playbacks.is_empty(), "real playback objects observed")
		# Do not stop them: exercise the same scene teardown as the UI.
		if restart == 1:
			level.hud.menu_requested.emit()
			await process_frame
			await process_frame
		else:
			await load_scene("res://scenes/launcher.tscn")
		check(current_scene.scene_file_path == "res://scenes/launcher.tscn", "return to menu while audio plays")
		level = null
		sound = null
		target = null
		await process_frame
		check(level_ref.get_ref() == null and sound_ref.get_ref() == null, "old level and its player pool are freed")
		check(await AudioProbe.drain(self), "mixer releases stopped playback references after transition")
		await process_frame
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		check(orphans <= baseline, "orphan nodes return to menu baseline")
	# Also verify natural completion with no explicit stop or transition.
	await load_scene("res://scenes/level/sky_bridge.tscn")
	current_scene.set_physics_process(false)
	for i in range(6):
		current_scene.sound.play_effect("impact")
	check(await AudioProbe.drain(self), "temporary impact playbacks naturally finish and are released")
	await process_frame
	check(current_scene.sound.voices.all(func(voice): return not voice.playing and voice.stream == null), "completed pooled voices release their stream references")
	for restart in range(3):
		var old_level = current_scene
		var old_ref: WeakRef = weakref(old_level)
		old_level.sound.play_effect("rifle")
		old_level.hud.retry_requested.emit()
		old_level = null
		await process_frame
		await process_frame
		check(old_ref.get_ref() == null and current_scene.scene_file_path == "res://scenes/level/sky_bridge.tscn", "retry reloads and frees the previous gameplay scene")
		current_scene.set_physics_process(false)
		check(await AudioProbe.drain(self), "retry releases previous gameplay audio")
	await load_scene("res://scenes/launcher.tscn")
	print("Audio lifecycle test failures: ", failures)
	quit(1 if failures else 0)
