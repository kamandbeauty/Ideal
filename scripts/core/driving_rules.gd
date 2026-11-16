class_name DrivingRules
extends RefCounted
## Small deterministic geometry helpers shared by spawning, diagnostics & tests.
## Motion itself is swept by CharacterBody3D against cars and solid obstacles.

const ACCELERATION := 2.1
const BRAKING := 6.0
const BUMPER_GAP := 0.32


static func stopping_speed(free_distance: float, cruise: float) -> float:
	return minf(cruise, sqrt(maxf(0.0, 2.0 * BRAKING * (free_distance - BUMPER_GAP))))


static func approach_speed(speed: float, target: float, delta: float) -> float:
	return move_toward(speed, target, (ACCELERATION if target > speed else BRAKING) * maxf(delta, 0.0))


static func extent(half_size: Vector2, forward: Vector2, axis: Vector2) -> float:
	var right := Vector2(forward.y, -forward.x)
	return absf(right.dot(axis)) * half_size.x + absf(forward.dot(axis)) * half_size.y


## Oriented bounding boxes include tyres and bumpers, not just the painted body.
static func overlaps(
	a: Vector2, a_size: Vector2, a_yaw: float, b: Vector2, b_size: Vector2, b_yaw: float, margin: float = 0.0
) -> bool:
	var af := Vector2(sin(a_yaw), cos(a_yaw))
	var bf := Vector2(sin(b_yaw), cos(b_yaw))
	var axes: Array[Vector2] = [af, Vector2(af.y, -af.x), bf, Vector2(bf.y, -bf.x)]
	for axis in axes:
		var distance := absf((b - a).dot(axis))
		var occupied := extent(a_size * 0.5, af, axis) + extent(b_size * 0.5, bf, axis)
		if distance >= occupied + margin:
			return false
	return true


static func xz(pos: Vector3) -> Vector2:
	return Vector2(pos.x, pos.z)
