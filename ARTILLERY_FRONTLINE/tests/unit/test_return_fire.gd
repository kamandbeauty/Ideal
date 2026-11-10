extends RefCounted
func run(t: TestContext) -> void:
	var fire := ReturnFire.new()
	var destroyed: Array = [0]
	fire.battery_destroyed.connect(func(): destroyed[0] += 1)
	t.equal(fire.health_ratio(), 1.0, "Battery starts at full health")
	fire.resolve_shell(null, Vector3.ZERO, false)
	t.equal(fire.battery_health, ReturnFire.BATTERY_MAX, "A miss does not damage the battery")
	fire.resolve_shell(null, Vector3.ZERO, true)
	t.equal(fire.battery_health, ReturnFire.BATTERY_MAX - ReturnFire.HIT_DAMAGE, "A hit deducts one hit of damage")
	var remaining_hits: int = int(ceil(ReturnFire.BATTERY_MAX / ReturnFire.HIT_DAMAGE)) - 1
	for index in range(remaining_hits):
		fire.resolve_shell(null, Vector3.ZERO, true)
	t.check(fire.battery_health <= 0.0 and destroyed[0] == 1, "Enough hits destroy the battery exactly once")
	fire.resolve_shell(null, Vector3.ZERO, true)
	t.equal(destroyed[0], 1, "A destroyed battery does not signal again")
	fire.free()
