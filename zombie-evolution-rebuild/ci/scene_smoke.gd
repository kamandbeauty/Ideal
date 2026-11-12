extends SceneTree

const AudioProbe = preload("res://ci/audio_probe.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := OS.get_environment("CI_SMOKE_SCENE")
	var frames := int(OS.get_environment("CI_SMOKE_FRAMES"))
	if change_scene_to_file(path) != OK:
		printerr("FAIL: smoke scene could not be loaded: ", path)
		quit(1)
		return
	await process_frame
	await process_frame
	for i in range(frames):
		await process_frame
	if current_scene != null and current_scene.get("sound") != null:
		current_scene.sound.stop_all()
	var ok: bool = await AudioProbe.drain(self)
	quit(0 if ok else 1)
