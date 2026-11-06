class_name Ballistics
extends RefCounted
## The same fixed-step integrator is used by prediction and live projectiles.

const STEP: float = 1.0 / 60.0
const WORLD_MASK: int = 3  # 1: environment, 2: damageable targets


static func advance(
	position: Vector3, velocity: Vector3, delta: float, gravity: float, drag: float = 0.0
) -> Dictionary:
	var acceleration := Vector3.DOWN * gravity - velocity * maxf(drag, 0.0)
	return {
		"position": position + velocity * delta + acceleration * (0.5 * delta * delta),
		"velocity": velocity + acceleration * delta,
	}


static func trace(
	space: PhysicsDirectSpaceState3D,
	origin: Vector3,
	initial_velocity: Vector3,
	gravity: float,
	drag: float = 0.0,
	max_time: float = 9.0
) -> Dictionary:
	var position := origin
	var velocity := initial_velocity
	var segment_start := origin
	var points := PackedVector3Array([origin])
	var elapsed := 0.0
	var max_steps := int(ceil(max_time / STEP))
	# Integrate at the physics step; cast one short chord every four steps.
	# The chord differs from the parabola by less than a centimetre at Earth gravity.
	for i in range(max_steps):
		var state := advance(position, velocity, STEP, gravity, drag)
		position = state["position"]
		velocity = state["velocity"]
		elapsed += STEP
		if (i + 1) % 4 != 0 and i + 1 != max_steps:
			continue
		var query := PhysicsRayQueryParameters3D.create(segment_start, position, WORLD_MASK)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			points.append(hit["position"])
			return {
				"points": points,
				"position": hit["position"],
				"collider": hit["collider"],
				"hit": true,
				"time": elapsed
			}
		points.append(position)
		segment_start = position
	return {"points": points, "position": position, "collider": null, "hit": false, "time": elapsed}
