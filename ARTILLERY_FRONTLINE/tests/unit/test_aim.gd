extends RefCounted
## Aim limits, drag response, smoothing and recoil of the mounted gun.


func run(t: TestContext) -> void:
	var shipped: AimSettings = load("res://resources/aim/default_aim.tres")
	t.check(shipped != null, "default_aim.tres loads as AimSettings")
	t.near(shipped.yaw_min_degrees, -70.0, 0.001, "shipped yaw minimum is -70")
	t.near(shipped.yaw_max_degrees, 70.0, 0.001, "shipped yaw maximum is +70")
	t.near(shipped.pitch_min_degrees, -15.0, 0.001, "shipped pitch minimum is -15 (down)")
	t.near(shipped.pitch_max_degrees, 45.0, 0.001, "shipped pitch maximum is +45 (up)")

	var settings: AimSettings = shipped.duplicate()
	var aim := AimController.new(settings)
	t.near(aim.yaw, settings.start_yaw_degrees, 0.001, "aim starts at the configured yaw")
	t.near(aim.pitch, settings.start_pitch_degrees, 0.001, "aim starts at the configured pitch")

	# Direction convention.
	t.check(AimController.direction_of(0.0, 0.0).is_equal_approx(Vector3(0, 0, -1)), "zero aim looks down -Z")
	t.check(AimController.direction_of(90.0, 0.0).is_equal_approx(Vector3(1, 0, 0)), "positive yaw turns right (+X)")
	t.check(AimController.direction_of(0.0, 45.0).y > 0.7, "positive pitch looks up")
	t.check(AimController.direction_of(0.0, -15.0).y < -0.25, "negative pitch looks down")

	# Drag directions and scale.
	aim.set_aim(0.0, 0.0)
	aim.drag(Vector2(100.0, 0.0))
	t.near(aim.target_yaw, 100.0 * settings.degrees_per_pixel, 0.0001, "dragging right turns right by degrees_per_pixel")
	t.near(aim.target_pitch, 0.0, 0.0001, "a horizontal drag leaves pitch alone")
	aim.set_aim(0.0, 0.0)
	aim.drag(Vector2(0.0, -100.0))
	t.near(aim.target_pitch, 100.0 * settings.degrees_per_pixel * settings.vertical_ratio, 0.0001, "dragging up raises the muzzle")
	aim.set_aim(0.0, 0.0)
	aim.drag(Vector2(0.0, -100.0), 1.0, true)
	t.check(aim.target_pitch < 0.0, "inverted vertical axis lowers the muzzle on an upward drag")
	aim.set_aim(0.0, 0.0)
	aim.drag(Vector2(50.0, 0.0), 2.0)
	t.near(aim.target_yaw, 100.0 * settings.degrees_per_pixel, 0.0001, "sensitivity multiplies the turn")

	# Limits hold however far the finger travels.
	aim.set_aim(0.0, 0.0)
	aim.drag(Vector2(99999.0, 99999.0))
	t.near(aim.target_yaw, 70.0, 0.0001, "yaw stops at +70")
	t.near(aim.target_pitch, -15.0, 0.0001, "pitch stops at -15")
	aim.drag(Vector2(-999999.0, -999999.0))
	t.near(aim.target_yaw, -70.0, 0.0001, "yaw stops at -70")
	t.near(aim.target_pitch, 45.0, 0.0001, "pitch stops at +45")
	aim.set_aim(500.0, -500.0)
	t.near(aim.yaw, 70.0, 0.0001, "set_aim clamps yaw")
	t.near(aim.pitch, -15.0, 0.0001, "set_aim clamps pitch")

	# The limits are data, not constants.
	settings.yaw_min_degrees = -25.0
	settings.yaw_max_degrees = 40.0
	settings.pitch_min_degrees = -5.0
	settings.pitch_max_degrees = 20.0
	aim.drag(Vector2(99999.0, -99999.0))
	t.near(aim.target_yaw, 40.0, 0.0001, "a changed yaw maximum is respected")
	t.near(aim.target_pitch, 20.0, 0.0001, "a changed pitch maximum is respected")
	aim.drag(Vector2(-99999.0, 99999.0))
	t.near(aim.target_yaw, -25.0, 0.0001, "a changed yaw minimum is respected")
	t.near(aim.target_pitch, -5.0, 0.0001, "a changed pitch minimum is respected")

	# Smoothing: eases toward the target, never overshoots, converges.
	settings = shipped.duplicate()
	aim = AimController.new(settings)
	aim.set_aim(0.0, 0.0)
	aim.turn(30.0, 10.0)
	aim.step(1.0 / 60.0)
	t.check(aim.yaw > 0.0 and aim.yaw < 30.0, "one frame moves part of the way (smooth response)")
	var previous: float = aim.yaw
	var monotonic: bool = true
	for index: int in 90:
		aim.step(1.0 / 60.0)
		if aim.yaw < previous - 0.00001 or aim.yaw > 30.0 + 0.00001:
			monotonic = false
		previous = aim.yaw
	t.check(monotonic, "smoothing never overshoots or backs up")
	t.near(aim.yaw, 30.0, 0.01, "yaw settles on the target")
	t.near(aim.pitch, 10.0, 0.01, "pitch settles on the target")
	settings.smoothing_speed = 0.0
	aim.turn(-10.0, 0.0)
	aim.step(1.0 / 60.0)
	t.near(aim.yaw, 20.0, 0.0001, "smoothing 0 follows the input exactly")

	# Recoil: bounded, recovers, never pushes the gun past its stops.
	settings = shipped.duplicate()
	aim = AimController.new(settings)
	aim.set_aim(0.0, 0.0)
	for index: int in 400:
		aim.kick(1.0, 1.0)
	t.check(aim.recoil_pitch <= settings.recoil_max_degrees + 0.0001, "recoil climb is capped")
	t.check(absf(aim.recoil_yaw) <= settings.recoil_max_degrees * 0.5 + 0.0001, "sideways recoil is capped")
	t.check(aim.aim_pitch() > aim.pitch, "recoil lifts the muzzle")
	for index: int in 180:
		aim.step(1.0 / 60.0)
	t.near(aim.recoil_pitch, 0.0, 0.01, "recoil recovers on its own")
	t.near(aim.aim_pitch(), 0.0, 0.02, "the aim returns to where the player left it")
	aim.set_aim(70.0, 45.0)
	for index: int in 50:
		aim.kick(1.0, 1.0)
	t.check(aim.aim_pitch() <= 45.0 + 0.0001, "recoil cannot exceed the pitch limit")
	t.check(aim.aim_yaw() <= 70.0 + 0.0001, "recoil cannot exceed the yaw limit")
	aim.reset()
	t.near(aim.recoil_pitch, 0.0, 0.0001, "reset clears recoil")
