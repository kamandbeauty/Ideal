class_name Ballistics
extends RefCounted
## Exact constant-gravity / optional linear-drag integration.
## Prediction and live shells call this SAME function; no duplicate Euler model.
const GRAVITY := Vector3(0.0, -9.81, 0.0)
const MAX_FLIGHT_TIME: float = 40.0

static func integrate(origin: Vector3, velocity: Vector3, seconds: float, drag: float = 0.0) -> Dictionary:
	var dt: float = maxf(seconds, 0.0)
	var k: float = maxf(drag, 0.0)
	if k < 0.000001:
		return {"position": origin + velocity * dt + GRAVITY * (0.5 * dt * dt), "velocity": velocity + GRAVITY * dt}
	var decay: float = exp(-k * dt)
	var terminal: Vector3 = GRAVITY / k
	var displacement: Vector3 = terminal * dt + (velocity - terminal) * ((1.0 - decay) / k)
	return {"position": origin + displacement, "velocity": terminal + (velocity - terminal) * decay}

static func direction(yaw_degrees: float, elevation_degrees: float) -> Vector3:
	var yaw: float = deg_to_rad(yaw_degrees)
	var pitch: float = deg_to_rad(elevation_degrees)
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()

static func solution(origin: Vector3, target: Vector3, speed: float, high_arc: bool = false, drag: float = 0.0) -> Dictionary:
	var flat := Vector2(target.x - origin.x, target.z - origin.z)
	var distance: float = flat.length()
	if distance < 0.01 or speed < 0.01:
		return {"valid": false, "yaw": 0.0, "elevation": 45.0, "flight_time": 0.0}
	var pitch: float = 0.0
	var time: float = 0.0
	if drag < 0.000001:
		var v2: float = speed * speed
		var discriminant: float = v2 * v2 - 9.81 * (9.81 * distance * distance + 2.0 * (target.y - origin.y) * v2)
		if discriminant < 0.0:
			return {"valid": false, "yaw": 0.0, "elevation": 45.0, "flight_time": 0.0}
		var root: float = sqrt(discriminant)
		pitch = atan((v2 + (root if high_arc else -root)) / (9.81 * distance))
		time = distance / (speed * cos(pitch))
	else:
		# Newton iterations on the exact horizontal-range equation.
		pitch = deg_to_rad(55.0 if high_arc else 15.0)
		for _iteration in range(14):
			var horizontal_speed: float = speed * cos(pitch)
			time = -log(maxf(0.00001, 1.0 - distance * drag / horizontal_speed)) / drag
			var state: Dictionary = integrate(origin, direction(0.0, rad_to_deg(pitch)) * speed, time, drag)
			var error: float = state.position.y - target.y
			var epsilon: float = 0.0001
			var next_state: Dictionary = integrate(origin, direction(0.0, rad_to_deg(pitch + epsilon)) * speed, time, drag)
			var derivative: float = (next_state.position.y - state.position.y) / epsilon
			if absf(derivative) < 0.001:
				break
			pitch = clampf(pitch - error / derivative, deg_to_rad(1.0), deg_to_rad(80.0))
		var end_state: Dictionary = integrate(origin, direction(0.0, rad_to_deg(pitch)) * speed, time, drag)
		if absf(end_state.position.y - target.y) > 1.0 or not is_finite(time):
			return {"valid": false, "yaw": 0.0, "elevation": 45.0, "flight_time": 0.0}
	var yaw: float = wrapf(atan2(-(target.x - origin.x), -(target.z - origin.z)), -PI, PI)
	return {"valid": true, "yaw": rad_to_deg(yaw), "elevation": rad_to_deg(pitch), "flight_time": time}

static func predict(origin: Vector3, velocity: Vector3, drag: float = 0.0, interval: float = 0.08) -> PackedVector3Array:
	var points := PackedVector3Array([origin])
	var time: float = 0.0
	while time < MAX_FLIGHT_TIME:
		time += interval
		var state: Dictionary = integrate(origin, velocity, time, drag)
		points.append(state.position)
		if state.position.y < -30.0:
			break
	return points
