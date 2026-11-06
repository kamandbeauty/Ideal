extends RefCounted

func run(t: TestContext) -> void:
	t.check(CoastalWeapon.ORDER.size() == 4, "Four mounted weapon types are defined")
	t.check(bool(CoastalWeapon.WEAPONS.twin_hmg.automatic), "Twin heavy machine gun supports automatic fire")
	t.check(float(CoastalWeapon.WEAPONS.rocket.blast) > 0.0, "Rocket ammunition has blast radius")
	var waves := WaveManager.new()
	waves.start()
	t.equal(waves.remaining, 8, "First landing wave fields eight soldiers")
	for index in range(8):
		waves.register_kill()
	waves.tick(3.2)
	t.equal(waves.round_index, 1, "Clearing a wave advances the round")
	t.equal(waves.remaining, 12, "Second wave increases pressure")
	var soldier := EnemySoldier.new()
	t.tree.root.add_child(soldier)
	soldier.configure(Vector3(0, 0, -20), Vector3(0, 0, 40), Vector3(4, 0, 20))
	soldier.receive_damage(200.0)
	t.check(soldier.is_dead(), "Soldier health state reaches death")
	soldier.queue_free()
	var scene: CoastalController = load("res://scenes/coastal/coastal_milestone.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	t.check(scene.soldiers.size() >= 8, "Playable milestone spawns animated infantry")
	t.check(scene.craft != null, "Playable milestone includes amphibious craft")
	scene.weapon.cooldown = 0.0
	var ammo: int = scene.weapon.ammo
	t.check(scene.fire_once(), "Mounted weapon fires")
	t.equal(scene.weapon.ammo, ammo - 1, "Firing consumes ammunition")
	var yaw: float = scene.yaw_target
	scene.aim_drag(Vector2(120.0, -20.0))
	t.check(not is_equal_approx(yaw, scene.yaw_target), "Aim input changes traverse")
	scene.set_auto_fire(true)
	t.check(scene.auto_fire, "Automatic fire toggle state is exposed")
	scene.queue_free()
	await t.tree.process_frame
