class_name IsometricCamera
extends Node3D
## Fixed-angle isometric rig: quarter turns, pinch/wheel zoom and drag panning.

const PITCH := 39.0
const ZOOM_MIN := 9.0
const ZOOM_MAX := 48.0
const ZOOM_STEP := 0.9
const PAN_LIMIT := 16.0

var target := Vector3.ZERO
var yaw := 35.0
var zoom := 30.0
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.4
	camera.far = 220.0
	add_child(camera)
	apply()


func apply() -> void:
	position = target
	rotation_degrees = Vector3(0, yaw, 0)
	if camera == null:
		return
	var radians := deg_to_rad(PITCH)
	camera.position = Vector3(0, sin(radians) * zoom, cos(radians) * zoom)
	camera.rotation_degrees = Vector3(-PITCH, 0, 0)


func pan_by_pixels(pixels: Vector2) -> void:
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var speed := zoom * 0.0016
	target += (-right * pixels.x + forward * pixels.y) * speed
	target.x = clampf(target.x, -PAN_LIMIT, PAN_LIMIT)
	target.z = clampf(target.z, -PAN_LIMIT, PAN_LIMIT)
	apply()


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	apply()


func turn_quarter(direction: int) -> void:
	yaw = fposmod(yaw + 90.0 * float(direction), 360.0)
	apply()


func focus_on(point: Vector3) -> void:
	target = Vector3(
		clampf(point.x, -PAN_LIMIT, PAN_LIMIT),
		0.0,
		clampf(point.z, -PAN_LIMIT, PAN_LIMIT)
	)
	apply()


func reset_view() -> void:
	yaw = 35.0
	zoom = 30.0
	target = Vector3.ZERO
	apply()
