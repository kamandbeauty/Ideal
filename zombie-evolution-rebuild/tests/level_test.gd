extends SceneTree

const AudioProbe = preload("res://ci/audio_probe.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
	else:
		print("PASS: " + description)

func run_test() -> void:
	var level = load("res://scenes/level/sky_bridge.tscn").instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(level.enemies.size() == 13, "waves created")
	var target = level.enemies[0]
	target.position = Vector3(0, 0.05, 7)
	await physics_frame
	var before: float = target.health
	level.shoot_at(level.hero, target.global_position + Vector3(0, 1.2, 0), 18.0)
	check(target.health < before, "raycast deals damage to a zombie")
	check(target.hit_reaction_time > 0, "zombie responds visually to damage")
	check(level.find_child("ImpactSparks", false, false) is CPUParticles3D, "damage creates impact particles")
	target.apply_damage(10000)
	check(level.kills == 1 and level.coins == 5, "enemy death updates counters")
	check(target.dead and target.collision_layer == 0, "defeated zombie stops colliding while its death motion plays")
	level.hero.position = Vector3(3, 0.05, 57)
	await physics_frame
	level.shoot_at(level.hero, level.gate.global_position + Vector3(3, 2, 0), 18.0)
	check(level.gate.selection == 0 and level.soldiers.is_empty(), "shooting does not select a gate")
	level.hero.position.z = 64.99
	level._physics_process(0.016)
	check(level.gate.selection == 1 and level.gate.finished, "crossing the red lane selects it")
	check(level.soldiers.size() == 3, "crossing the red gate recruits three soldiers")
	level.gate.check_crossing(level.hero.global_position)
	check(level.soldiers.size() == 3, "crossing cannot recruit twice")
	level.soldiers[0].apply_damage(1000)
	check(level.soldiers.size() == 2, "soldier damage removes a soldier")
	level.soldiers[1].apply_damage(1000)
	var soldier = level.soldiers[0]
	soldier.position = Vector3(0, 0.05, 75)
	level.hero.position = Vector3(0, 0.05, 77)
	level.spawn_enemy("zombie", Vector3(0, 0.05, 80))
	var squad_target = level.enemies.back()
	await physics_frame
	await physics_frame
	var target_health: float = squad_target.health
	soldier.fire_timer = 0
	level.update_squad(0.016)
	check(squad_target.health < target_health, "soldier independently shoots a zombie")
	var hero_health: float = level.hero.health
	squad_target.position = level.hero.position + Vector3(0, 0, 1)
	soldier.position = Vector3(-4, 0.05, 70)
	squad_target.attack_timer = 0
	level.update_enemies(0.016)
	check(level.hero.health < hero_health, "zombie attacks nearby hero")
	level.on_gate_crossed("double")
	check(level.soldiers.size() == 3, "double counts hero separately")
	level.on_gate_crossed("add3")
	level.on_gate_crossed("add3")
	level.on_gate_crossed("add3")
	check(level.soldiers.size() == 10, "squad maximum enforced")
	for enemy in level.enemies.duplicate():
		enemy.apply_damage(10000)
	level.hero.position.z = level.END_Z
	level._physics_process(0.016)
	check(not level.running and level.hud.end_panel.visible, "victory state appears")
	level.sound.stop_all()
	level.queue_free()
	await process_frame
	if not await AudioProbe.drain(self):
		failures += 1
	print("Level integration failures: ", failures)
	quit(1 if failures else 0)
