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
		actor.velocity = Vector3(0, 0, 2.6)
		actor.update_animation(0.17, true)
		if left >= 0 and right >= 0 and arm >= 0:
			check(absf(actor.rig.get_bone_pose_rotation(left).x) > 0.1 and actor.rig.get_bone_pose_rotation(left).x * actor.rig.get_bone_pose_rotation(right).x < 0, "hero legs move in opposite directions")
			var expected: Vector3 = actor.to_local(actor.rig.to_global(actor.rig.get_bone_global_pose(arm) * Vector3(-18, -13, 0)))
			check(actor.weapon.position.distance_to(expected) < 0.01, "hero weapon follows the hand")
			actor.update_animation(0.3, false)
			check(actor.gait_blend == 0.0 and absf(actor.rig.get_bone_pose_rotation(left).x) < 0.001, "hero gait smoothly returns to idle")
	actor.queue_free()
	var soldier = Character.new()
	root.add_child(soldier)
	soldier.setup("soldier")
	check(Character.MODEL_CONFIG["soldier"][0] == Character.MODEL_CONFIG["hero"][0], "soldier uses the same hero model")
	check(is_instance_valid(soldier.rig), "soldier has the same hero skeleton")
	if soldier.rig:
		var left: int = soldier.rig.find_bone("LegLeft")
		var right: int = soldier.rig.find_bone("LegRight")
		var arm: int = soldier.rig.find_bone("ArmRight")
		check(left >= 0 and right >= 0 and arm >= 0, "soldier has matching leg and arm bones")
		soldier.velocity = Vector3(0, 0, 2.6)
		soldier.update_animation(0.17, true)
		if left >= 0 and right >= 0 and arm >= 0:
			check(soldier.rig.get_bone_pose_rotation(left).x * soldier.rig.get_bone_pose_rotation(right).x < 0, "soldier legs move in opposite directions")
			var expected: Vector3 = soldier.to_local(soldier.rig.to_global(soldier.rig.get_bone_global_pose(arm) * Vector3(-18, -13, 0)))
			check(soldier.weapon.position.distance_to(expected) < 0.01, "soldier weapon follows the hand")
			soldier.show_shot()
			check(soldier.muzzle_flash.visible and soldier.combat_animation_time > 0.0, "soldier fires with muzzle and recoil feedback")
			soldier.update_animation(0.3, false)
			check(soldier.gait_blend == 0.0 and absf(soldier.rig.get_bone_pose_rotation(left).x) < 0.001, "soldier gait returns to idle")
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
	var a: Vector3 = level.formation_position(0, 10)
	var b: Vector3 = level.formation_position(1, 10)
	var c: Vector3 = level.formation_position(2, 10)
	check(a.x < level.hero.position.x and b.x > level.hero.position.x, "crescent spans both sides of the hero")
	check(not is_equal_approx(a.z, b.z) and not is_equal_approx(a.z, c.z), "crescent uses irregular depth rather than rows")
	for i in range(10):
		var point: Vector3 = level.formation_position(i, 10)
		check(absf(point.x) < 5.6 and point.z < level.hero.position.z, "formation slot stays behind hero and on bridge")
		for j in range(i):
			check(point.distance_to(level.formation_position(j, 10)) >= 1.0, "crescent slots stay separated")
	check(level.find_child("CityEntrance", true, false) is Node3D, "city entrance exists at bridge end")
	var city = level.find_child("CityBuildings", true, false)
	check(city is Node3D and city.get_child_count() > 10, "city facade sits beyond the entrance")
	var brute = level.enemies.back()
	check(brute.role == "brute" and is_equal_approx(brute.position.z, 160.0), "stage brute begins in front of the city")
	level.hero.position.z = 130
	var guard_z: float = brute.position.z
	level.update_enemies(0.016)
	check(is_equal_approx(brute.position.z, guard_z), "brute guards the entrance before approach")
	level.sound.stop_all()
	level.queue_free()
	await process_frame
	if not await AudioProbe.drain(self):
		failures += 1
	print("Character and firing test failures: ", failures)
	quit(1 if failures else 0)
