extends SceneTree

const LevelScene = preload("res://scenes/level/sky_bridge.tscn")
const EnvironmentScript = preload("res://scripts/level/environment.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func run_tests() -> void:
	var environment = EnvironmentScript.new()
	root.add_child(environment)
	await process_frame
	var structure = environment.find_child("BridgeSuperstructure", true, false)
	check(structure is Node3D, "bridge has a dedicated suspension superstructure")
	if structure is Node3D:
		check(structure.get_child_count() >= 30, "bridge superstructure contains detailed portals, lamps and deck joints")
	var level = LevelScene.instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await process_frame
	check(level.camera.fov <= 50.0, "elevated gameplay camera uses a tighter field of view")
	check(level.camera.position.y >= 11.0, "gameplay camera uses the requested elevated top view")
	var target := Vector3(0, 0.85, 9.0)
	var forward: Vector3 = -level.camera.global_transform.basis.z
	check(forward.dot((target - level.camera.global_position).normalized()) > 0.995, "camera points toward the forward gameplay lane")
	check(level.hero.position.z == 2.0 and level.gate.position.z == 65.0, "camera pass preserves player start and gate placement")
	check(level.fire_interval <= 0.15 and level.ammo == 30, "camera pass preserves automatic-fire configuration")
	level.sound.stop_all()
	level.queue_free()
	environment.queue_free()
	await process_frame
	print("Visual overhaul test failures: ", failures)
	quit(1 if failures else 0)
