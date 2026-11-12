class_name Ballistics
extends RefCounted
## Plain arithmetic of a thrown body: no drag, constant gravity.


## Launch velocity that carries a body from `from` to `to` in `time` seconds.
static func lob_velocity(from: Vector3, to: Vector3, time: float, gravity: float) -> Vector3:
	var flight: float = maxf(time, 0.05)
	var velocity: Vector3 = (to - from) / flight
	velocity.y += 0.5 * gravity * flight
	return velocity


static func position_at(from: Vector3, velocity: Vector3, time: float, gravity: float) -> Vector3:
	return from + velocity * time + Vector3(0.0, -0.5 * gravity * time * time, 0.0)


## Highest point of the arc above the launch point (0 when thrown downward).
static func apex_height(velocity: Vector3, gravity: float) -> float:
	if velocity.y <= 0.0 or gravity <= 0.0:
		return 0.0
	return velocity.y * velocity.y / (2.0 * gravity)


## Time of flight for a lob that covers `distance` of ground at `speed`.
static func flight_time(distance: float, speed: float, shortest: float, longest: float) -> float:
	return clampf(distance / maxf(speed, 0.1), shortest, longest)


## Moves `target` along the ground line from `origin` so it lies between the
## two ranges; the height of the target is kept.
static func clamp_range(origin: Vector3, target: Vector3, nearest: float, farthest: float) -> Vector3:
	var offset := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	var distance: float = offset.length()
	if distance < 0.001:
		return Vector3(origin.x, target.y, origin.z - nearest)
	var wanted: float = clampf(distance, nearest, farthest)
	if is_equal_approx(wanted, distance):
		return target
	var moved: Vector3 = offset / distance * wanted
	return Vector3(origin.x + moved.x, target.y, origin.z + moved.z)


## Velocity after striking a surface: `bounce` of the speed into the surface
## comes back out, `roll` of the speed along it survives.
static func rebound(velocity: Vector3, normal: Vector3, bounce: float, roll: float) -> Vector3:
	var into: Vector3 = normal * velocity.dot(normal)
	var along: Vector3 = velocity - into
	return along * roll - into * bounce
