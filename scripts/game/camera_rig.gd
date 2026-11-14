class_name CameraRig
extends Node3D
## An orbit camera: yaw around the focus point, fixed pitch range, dolly zoom.

const MIN_DISTANCE := 22.0
const MAX_DISTANCE := 60.0
const MIN_PITCH := 40.0
const MAX_PITCH := 68.0

var camera: Camera3D
var distance := 40.0
var pitch_degrees := 52.0
var yaw := 0.0
var focus := Vector3.ZERO


func setup(focus_point: Vector3) -> void:
	focus = focus_point
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 42.0
	camera.near = 0.5
	camera.far = 260.0
	camera.current = true
	add_child(camera)
	_apply()


func orbit(amount: float) -> void:
	yaw = wrapf(yaw + amount, -PI, PI)
	_apply()


func zoom_by(factor: float) -> void:
	distance = clampf(distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	_apply()


func _apply() -> void:
	position = focus
	rotation = Vector3(deg_to_rad(-pitch_degrees), yaw, 0.0)
	if camera != null:
		camera.position = Vector3(0.0, 0.0, distance)
