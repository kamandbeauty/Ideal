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
	var actor = Character.new()
	root.add_child(actor)
	actor.setup("hero")
	check(is_instance_valid(actor.rig), "hero has a skeleton")
	if actor.rig != null:
		var left: int = actor.rig.find_bone("LegLeft")
		var right: int = actor.rig.find_bone("LegRight")
		var arm: int = actor.rig.find_bone("ArmRight")
		check(left >= 0 and right >= 0 and arm >= 0, "hero has leg and arm bones")
		actor.update_animation(0.17, true)
		if left >= 0 and right >= 0 and arm >= 0:
			check(absf(actor.rig.get_bone_pose_rotation(left).x) > 0.1 and actor.rig.get_bone_pose_rotation(left).x * actor.rig.get_bone_pose_rotation(right).x < 0, "hero legs move in opposite directions")
			var expected: Vector3 = actor.to_local(actor.rig.to_global(actor.rig.get_bone_global_pose(arm) * Vector3(-18, -13, 0)))
			check(actor.weapon.position.distance_to(expected) < 0.01, "hero weapon follows the hand")
	actor.queue_free()
	var soldier = Character.new()
	root.add_child(soldier)
	soldier.setup("soldier")
	check(is_instance_valid(soldier.rig) and is_instance_valid(soldier.animation_player), "soldier has a skinned model with animation clips")
	if soldier.animation_player:
		soldier.update_animation(0.1, true)
		check(soldier.current_animation == "Walk_Carry" and soldier.animation_player.is_playing(), "soldier plays the walking animation")
		soldier.update_animation(0.1, false)
		check(soldier.current_animation == "Idle", "soldier transitions to idle")
		soldier.show_shot()
		soldier.update_animation(0.01, true)
		check(soldier.current_animation == "Shoot_OneHanded", "soldier plays the authored shooting clip")
		soldier.update_animation(0.3, true)
		check(soldier.current_animation == "Walk_Carry", "soldier resumes walk after shooting")
	soldier.queue_free()
	var level = load("res://scenes/level/sky_bridge.tscn").instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	await physics_frame
	var initial_z: float = level.hero.position.z
	level._physics_process(0.1)
	check(level.hero.position.z > initial_z, "hero moves through the world, not just the camera")
	check(level.ammo == 29 and level.hero.muzzle_flash.visible, "automatic fire starts without a button")
	level.hero.fire_timer = 0
	level._physics_process(0.016)
	check(level.ammo == 28, "automatic fire repeats between waves")
	level.on_gate_crossed("add3")
	var a: Vector3 = level.formation_position(0, 3)
	var b: Vector3 = level.formation_position(1, 3)
	var c: Vector3 = level.formation_position(2, 3)
	check(is_equal_approx(a.x + b.x, 2.0 * level.hero.position.x) and a.distance_to(b) >= 2.6, "front formation pair is symmetric and separated")
	check(absf(c.x - level.hero.position.x) >= 1.3 and c.z < a.z - 1.4, "third soldier stays behind and keeps the hero sightline clear")
	for i in range(10):
		check(absf(level.formation_position(i, 10).x) < 5.6, "formation slot stays on the bridge")
	level.sound.stop_all()
	level.queue_free()
	await process_frame
	if not await AudioProbe.drain(self):
		failures += 1
	print("Character and firing test failures: ", failures)
	quit(1 if failures else 0)
