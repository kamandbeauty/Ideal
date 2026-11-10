class_name AimAssist
extends RefCounted
## Touch aim assist: a gentle pull toward a hostile close to the crosshair that has a clear
## line of sight. It never snaps. The pull is capped per second, a chosen target is kept while
## it stays inside the capture cone (no flicker between targets), and anything behind cover
## (physics layer 1) is never selected. Pure helpers, so the rules are testable.

## A hostile whose chest is within this angle of the crosshair can attract the aim.
const CAPTURE_DEG: float = 2.5
## Pull speed at full strength, in degrees per second.
const MAX_PULL_DEG_PER_S: float = 4.0
## Fraction of the remaining angle closed per second at full strength.
const PULL_GAIN: float = 1.2
## Cover and terrain live on physics layer 1; hostiles and barrels do not, so the ray ignores them.
const COVER_LAYER: int = 1

## Yaw/pitch (degrees, same convention as the emplacement's aim targets) needed to face point from origin.
static func angles_to(origin: Vector3, point: Vector3) -> Vector2:
	var direction: Vector3 = point - origin
	if direction.length_squared() < 0.0001:
		return Vector2.ZERO
	direction = direction.normalized()
	var yaw: float = rad_to_deg(atan2(-direction.x, -direction.z))
	var pitch: float = rad_to_deg(asin(clampf(direction.y, -1.0, 1.0)))
	return Vector2(yaw, pitch)

## Angular offset (yaw, pitch) in degrees from the current aim to point. Yaw wraps to -180..180.
static func offset_to(origin: Vector3, aim_yaw: float, aim_pitch: float, point: Vector3) -> Vector2:
	var wanted: Vector2 = angles_to(origin, point)
	return Vector2(wrapf(wanted.x - aim_yaw, -180.0, 180.0), wanted.y - aim_pitch)

## Pull for one frame. Zero outside the capture cone, at zero strength, or with no time passed.
static func pull(offset: Vector2, strength: float, delta: float) -> Vector2:
	var amount: float = clampf(strength, 0.0, 1.0)
	if amount <= 0.0 or delta <= 0.0 or offset.length() > CAPTURE_DEG:
		return Vector2.ZERO
	var step: Vector2 = offset * PULL_GAIN * amount * delta
	var limit: float = MAX_PULL_DEG_PER_S * amount * delta
	return Vector2(clampf(step.x, -limit, limit), clampf(step.y, -limit, limit))

## True when nothing on cover layers blocks the straight line from `from` to `to`.
static func line_clear(world: World3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, COVER_LAYER)
	return world.direct_space_state.intersect_ray(query).is_empty()

## Picks the hostile to assist. `aim_point_of` maps a target to the point it is aimed at,
## `visible` is a Callable(point) -> bool for line of sight. The previous target is kept while it
## stays valid, so the assist does not hop between targets.
static func choose(origin: Vector3, aim_yaw: float, aim_pitch: float, targets: Array, visible: Callable, previous: Node3D) -> Node3D:
	var best: Node3D = null
	var best_length: float = CAPTURE_DEG
	for entry in targets:
		var target := entry as Node3D
		if target == null or not is_instance_valid(target):
			continue
		var point: Vector3 = target.global_position + Vector3.UP * 1.2
		var length: float = offset_to(origin, aim_yaw, aim_pitch, point).length()
		if length > CAPTURE_DEG:
			continue
		if not bool(visible.call(point)):
			continue
		if target == previous:
			return target
		if length < best_length:
			best_length = length
			best = target
	return best
