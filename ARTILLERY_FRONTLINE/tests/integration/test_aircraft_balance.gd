extends RefCounted
## Phase 3.6 aircraft checks: the flight prediction matches the orbit, a led shot meets a moving fighter
## while an unled shot does not, and aircraft stay unarmoured so ground weapons keep their damage.

## Bullet flight simulated in small steps when checking the closest approach to the aircraft.
const STEP: float = 0.001
## Twin HMG bullet speed (coastal_weapon.gd): the fastest player bullet (autocannon 380, cannon 260, bazooka 140, rocket 115).
const FAST_BULLET_SPEED: float = 430.0
## Camera height used for the sight line: about the emplacement ground plus the 1.65 m aim pivot (coastal_controller.gd).
const CAMERA_POSITION: Vector3 = Vector3(0.0, 5.7, 58.0)

func run(t: TestContext) -> void:
	_check_prediction_matches_orbit(t)
	_check_led_shot_meets_fighter(t)
	_check_aircraft_unarmoured(t)

func _check_prediction_matches_orbit(t: TestContext) -> void:
	var plane := EnemyAircraft.new()
	t.tree.root.add_child(plane)
	plane.configure(Vector3(0.0, 0.0, 58.0), "fighter", 0.4)
	plane.set_physics_process(false)
	t.check(plane.global_position.distance_to(plane.predicted_position(0.0)) < 0.001, "A zero-second prediction is where the aircraft is now")
	var later: Vector3 = plane.predicted_position(1.0)
	plane._update_position(1.0)
	t.check(plane.global_position.distance_to(later) < 0.001, "The prediction for one second ahead matches the aircraft one second later")
	plane.queue_free()

func _check_led_shot_meets_fighter(t: TestContext) -> void:
	var plane := EnemyAircraft.new()
	t.tree.root.add_child(plane)
	plane.configure(Vector3(0.0, 0.0, 58.0), "fighter", 0.0)
	plane.set_physics_process(false)
	var radius: float = (plane.collision.shape as SphereShape3D).radius
	var led: Vector3 = plane.intercept_point(CAMERA_POSITION, FAST_BULLET_SPEED)
	var unled: Vector3 = plane.global_position + Vector3.UP * 1.2
	var led_miss: float = _closest_approach(plane, CAMERA_POSITION, led, FAST_BULLET_SPEED)
	var unled_miss: float = _closest_approach(plane, CAMERA_POSITION, unled, FAST_BULLET_SPEED)
	t.check(led_miss <= radius, "A led shot passes inside a fighter moving at orbit speed (miss %.2f m, radius %.1f m)" % [led_miss, radius])
	t.check(unled_miss > radius, "The same shot without the lead misses the moving fighter (miss %.2f m)" % unled_miss)
	plane.queue_free()

func _check_aircraft_unarmoured(t: TestContext) -> void:
	for kind in ["helicopter", "fighter"]:
		var plane := EnemyAircraft.new()
		t.tree.root.add_child(plane)
		plane.configure(Vector3.ZERO, kind, 0.0)
		plane.set_physics_process(false)
		t.equal(plane.armor, 0.0, "%s: an aircraft has a formal armour rating of zero" % kind)
		t.equal(plane.damage_resistance(20.0), 0.0, "%s: an aircraft resists no damage from a machine-gun hit" % kind)
		var before: float = plane.health
		var removed: float = plane.receive_damage(20.0)
		t.equal(removed, 20.0, "%s: a 20-damage hit removes 20 health" % kind)
		t.equal(plane.health, before - 20.0, "%s: health falls by the full hit" % kind)
		plane.queue_free()

## Smallest distance between the bullet's straight path (from origin, toward aim, at speed) and the
## aircraft's centre over the bullet's life. The aircraft is sampled at the same instant as the bullet.
static func _closest_approach(plane: EnemyAircraft, origin: Vector3, aim: Vector3, speed: float) -> float:
	var direction: Vector3 = (aim - origin).normalized()
	var best: float = INF
	var tau: float = 0.0
	while tau <= 2.4:
		var bullet: Vector3 = origin + direction * speed * tau
		best = minf(best, bullet.distance_to(plane.predicted_position(tau)))
		tau += STEP
	return best
