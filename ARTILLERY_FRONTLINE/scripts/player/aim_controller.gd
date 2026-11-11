class_name AimController
extends RefCounted
## Aim state of the mounted gun. Pure logic so it can be tested without a scene:
## input moves a clamped target, the gun eases toward it, and recoil is a
## transient offset that recovers on its own.

var settings: AimSettings
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0
var recoil_yaw: float = 0.0
var recoil_pitch: float = 0.0


func _init(aim_settings: AimSettings) -> void:
	settings = aim_settings
	reset()


func reset() -> void:
	set_aim(settings.start_yaw_degrees, settings.start_pitch_degrees)
	recoil_yaw = 0.0
	recoil_pitch = 0.0


## Jumps straight to an aim, still inside the limits.
func set_aim(yaw_degrees: float, pitch_degrees: float) -> void:
	target_yaw = clampf(yaw_degrees, settings.yaw_min_degrees, settings.yaw_max_degrees)
	target_pitch = clampf(pitch_degrees, settings.pitch_min_degrees, settings.pitch_max_degrees)
	yaw = target_yaw
	pitch = target_pitch


## A finger moved `pixels` across the reference canvas. Dragging right turns
## right; dragging up raises the muzzle unless the player inverted the axis.
func drag(pixels: Vector2, sensitivity: float = 1.0, invert_y: bool = false) -> void:
	var scale: float = settings.degrees_per_pixel * sensitivity
	var vertical: float = pixels.y * scale * settings.vertical_ratio
	turn(pixels.x * scale, vertical if invert_y else -vertical)


func turn(yaw_delta: float, pitch_delta: float) -> void:
	target_yaw = clampf(target_yaw + yaw_delta, settings.yaw_min_degrees, settings.yaw_max_degrees)
	target_pitch = clampf(target_pitch + pitch_delta, settings.pitch_min_degrees, settings.pitch_max_degrees)


func step(delta: float) -> void:
	if settings.smoothing_speed <= 0.0:
		yaw = target_yaw
		pitch = target_pitch
	else:
		var blend: float = 1.0 - exp(-settings.smoothing_speed * delta)
		yaw = lerpf(yaw, target_yaw, blend)
		pitch = lerpf(pitch, target_pitch, blend)
	var decay: float = exp(-settings.recoil_recovery_speed * delta)
	recoil_yaw *= decay
	recoil_pitch *= decay


## One shot's worth of recoil. `sideways` is a random value in -1..1.
func kick(strength: float = 1.0, sideways: float = 0.0) -> void:
	recoil_pitch = minf(recoil_pitch + settings.recoil_pitch_degrees * strength, settings.recoil_max_degrees)
	var limit: float = settings.recoil_max_degrees * 0.5
	recoil_yaw = clampf(recoil_yaw + settings.recoil_yaw_degrees * strength * sideways, -limit, limit)


## Where the barrels actually point, recoil included, never outside the limits.
func aim_yaw() -> float:
	return clampf(yaw + recoil_yaw, settings.yaw_min_degrees, settings.yaw_max_degrees)


func aim_pitch() -> float:
	return clampf(pitch + recoil_pitch, settings.pitch_min_degrees, settings.pitch_max_degrees)


static func direction_of(yaw_degrees: float, pitch_degrees: float) -> Vector3:
	var yaw_rad: float = deg_to_rad(yaw_degrees)
	var pitch_rad: float = deg_to_rad(pitch_degrees)
	return Vector3(sin(yaw_rad) * cos(pitch_rad), sin(pitch_rad), -cos(yaw_rad) * cos(pitch_rad))


func direction() -> Vector3:
	return direction_of(aim_yaw(), aim_pitch())
