extends RefCounted
func run(t: TestContext) -> void:
	var world := Node3D.new()
	t.tree.root.add_child(world)
	var effects := EffectPool.new()
	world.add_child(effects)
	effects.apply_quality("low", Graphics.PROFILES.low)
	var data: EnemyData = load("res://resources/enemies/emplacement.tres").duplicate()
	data.model_path = ""
	var target := EnemyTarget.new()
	target.configure(data, "test_target", PackedVector3Array(), true)
	target.position = Vector3(0, 0, -20)
	world.add_child(target)
	var combat := CombatCoordinator.new()
	combat.effects = effects
	world.add_child(combat)
	var damages: Array[float] = []
	combat.damage_dealt.connect(func(_id, amount, _direct, _shot): damages.append(amount))
	var pool := ProjectilePool.new()
	world.add_child(pool)
	pool.impact.connect(combat.resolve_impact)
	var ammo: AmmunitionData = load("res://resources/ammunition/he.tres").duplicate()
	ammo.damage = 500.0
	t.check(pool.launch(Vector3(0, 3, 0), Vector3(0, 0, -40), ammo, 1.0, 1), "Pooled projectile launches")
	var frames: int = 0
	while not target.health.is_destroyed and frames < 180:
		await t.tree.physics_frame
		frames += 1
	t.check(target.health.is_destroyed, "Swept projectile collision destroys real target")
	t.check(not damages.is_empty(), "Impact emitted damage event")
	t.equal(pool.active_count(), 0, "Impacted shell returned to pool")
	t.equal(target.collision_layer, 0, "Destroyed target collision disabled")
	for index in range(30):
		effects.explode(Vector3(index, 0.1, 0), Vector3.UP, 10, 0)
	t.check(effects.active_count() <= 4, "Low profile bounds simultaneous explosions")
	t.check(effects.craters.size() == 24, "Crater decal pool is bounded")
	effects.clear()
	for index in range(12):
		t.check(pool.launch(Vector3(100, 100, 100), Vector3.UP * 5, ammo), "Projectile pool slot available")
	t.check(not pool.launch(Vector3(100, 100, 100), Vector3.UP * 5, ammo), "Projectile pool refuses unbounded allocation")
	pool.clear()
	t.equal(pool.active_count(), 0, "Projectile pool clears safely")
	var crate := Destructible.new()
	world.add_child(crate)
	crate.configure("test_crate", "crate", Vector3(2, 2, 2))
	crate.receive_damage(35, Vector3.ZERO, false)
	t.equal(crate.stage, 1, "Destructible intermediate damage state")
	crate.receive_damage(100, Vector3.ZERO, true)
	t.equal(crate.stage, 2, "Destructible final wreck state")
	t.check(crate.wreck.visible and not crate.intact.visible, "Prebuilt destruction state visible")
	world.free()
