extends SceneTree

const AudioProbe = preload("res://ci/audio_probe.gd")

const SoundScript = preload("res://scripts/level/sound_effects.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, text: String) -> void:
	if condition:
		print("PASS: ", text)
	else:
		failures += 1
		printerr("FAIL: ", text)

func run_tests() -> void:
	var level = load("res://scenes/level/sky_bridge.tscn").instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await process_frame
	check(level.sound.voices.size() == SoundScript.VOICE_COUNT, "audio voice pool initialized")
	for effect in ["rifle", "impact", "gate", "reload", "hurt", "victory", "defeat"]:
		check(SoundScript.EFFECTS[effect] is AudioStream, effect + " effect imported")
	var slot: int = level.sound.next_voice
	level.sound.play_effect("rifle")
	check(level.sound.voices[slot].stream == SoundScript.EFFECTS["rifle"], "firing selects rifle effect")
	level.show_bullet(Vector3(0, 1, 0), Vector3(0, 1, 12))
	check(level.visible_bullets.size() == 1 and level.visible_bullets[0].mesh is SphereMesh, "shot uses a short projectile instead of a beam")
	check(level.visible_bullets[0].mesh.height < 0.3, "bullet visual is not a full-length line")
	await create_timer(0.3).timeout
	check(level.visible_bullets.is_empty(), "bullet visual expires after flight")
	level.hero.show_shot()
	check(level.hero.muzzle_flash.visible, "shot shows muzzle flash")
	check(level.hero.muzzle_flash.mesh is QuadMesh and level.hero.muzzle_flash.material_override.albedo_texture is Texture2D, "muzzle flash uses the imported starburst texture")
	level.hero.update_animation(0.2, false)
	check(not level.hero.muzzle_flash.visible, "muzzle flash expires")
	var bus := AudioServer.get_bus_index("Master")
	var preferences = root.get_node("Preferences")
	var was_enabled: bool = preferences.sound_enabled
	preferences.sound_enabled = false
	preferences.apply_settings()
	check(AudioServer.is_bus_mute(bus), "sound preference mutes effects bus")
	preferences.sound_enabled = was_enabled
	preferences.apply_settings()
	level.sound.stop_all()
	level.queue_free()
	await process_frame
	if not await AudioProbe.drain(self):
		failures += 1
	print("Effects test failures: ", failures)
	quit(1 if failures else 0)
