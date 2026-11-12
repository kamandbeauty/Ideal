extends SceneTree

const Character = preload("res://scripts/level/character.gd")
const AudioProbe = preload("res://ci/audio_probe.gd")
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
	for role in ["hero", "soldier"]:
		var actor = Character.new()
		root.add_child(actor)
		actor.setup(role)
		check(is_instance_valid(actor.rig), role + " uses the skinned human model")
		if actor.rig != null:
			var left: int = actor.rig.find_bone("LegLeft")
			var right: int = actor.rig.find_bone("LegRight")
			var arm: int = actor.rig.find_bone("ArmRight")
			check(left >= 0 and right >= 0 and arm >= 0, role + " has leg and arm bones")
			actor.update_animation(0.17, true)
			if left >= 0 and right >= 0 and arm >= 0:
				check(absf(actor.rig.get_bone_pose_rotation(left).x) > 0.1 and actor.rig.get_bone_pose_rotation(left).x * actor.rig.get_bone_pose_rotation(right).x < 0, role + " legs move in opposite directions")
				check(absf(actor.rig.get_bone_pose_rotation(arm).y) > 0.1, role + " aims the arm")
				var expected: Vector3 = actor.to_local(actor.rig.to_global(actor.rig.get_bone_global_pose(arm) * Vector3(-18, -13, 0)))
				check(actor.weapon.position.distance_to(expected) < 0.01, role + " weapon follows the hand")
			actor.update_animation(0.016, false)
			if left >= 0:
				check(absf(actor.rig.get_bone_pose_rotation(left).x) < 0.001, role + " legs return to idle")
		actor.queue_free()
	var level = load("res://scenes/level/sky_bridge.tscn").instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(level.nearest_enemy(level.hero.position, 27.0) == null, "test starts between enemy waves")
	var ammo: int = level.ammo
	level._physics_process(0.016)
	check(level.ammo == ammo - 1, "hero fires even without a target")
	check(level.hero.muzzle_flash.visible, "automatic shot shows the muzzle flash")
	level.hero.fire_timer = 0
	level._physics_process(0.016)
	check(level.ammo == ammo - 2, "automatic fire repeats and consumes ammo")
	level.sound.stop_all()
	level.queue_free()
	await process_frame
	if not await AudioProbe.drain(self):
		failures += 1
	print("Character and firing test failures: ", failures)
	quit(1 if failures else 0)
