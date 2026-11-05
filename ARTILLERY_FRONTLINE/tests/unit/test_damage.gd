extends RefCounted
func run(t: TestContext) -> void:
	t.near(DamageSystem.calculate(100, 0, 10), 100, 0.001, "Center blast")
	t.near(DamageSystem.calculate(100, 10, 10), 0, 0.001, "Blast boundary")
	t.near(DamageSystem.calculate(100, 11, 10), 0, 0.001, "Outside blast")
	t.check(DamageSystem.calculate(100, 3, 10) > DamageSystem.calculate(100, 7, 10), "Monotonic falloff")
	t.near(DamageSystem.calculate(100, 100, 5, 0.25, true, 1.5), 133.125, 0.001, "Direct armor penetration")
	t.near(DamageSystem.calculate(-5, 0, 10), 0, 0.001, "Negative damage rejected")
	var health := HealthComponent.new()
	health.maximum = 100.0
	t.tree.root.add_child(health)
	var destruction: Array[int] = [0]
	health.destroyed.connect(func(): destruction[0] += 1)
	t.near(health.apply_damage(60), 60, 0.001, "Damage applied")
	t.near(health.current, 40, 0.001, "Health reduced")
	t.near(health.apply_damage(80), 40, 0.001, "Overkill clamped")
	health.apply_damage(80)
	t.equal(destruction[0], 1, "Destroyed signal emitted exactly once")
	health.free()
