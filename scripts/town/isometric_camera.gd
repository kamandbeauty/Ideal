class_name IsometricCamera
extends Node3D
## True orthographic toy-town framing: parallel roads and readable pitched
## roofs, with the same touch pan, pinch zoom and quarter-turn controls.

const PITCH := 45.0
const ORTHO_SCALE := 0.72
const ZOOM_MIN := 11.0
const ZOOM_MAX := 58.0
const ZOOM_STEP := 0.9
const PAN_LIMIT := 13.0
const DEFAULT_YAW := 45.0
const DEFAULT_ZOOM := 36.0
const DEFAULT_TARGET := Vector3(1.6, 0.0, 2.8)

var target := DEFAULT_TARGET
var yaw := DEFAULT_YAW
var zoom := DEFAULT_ZOOM
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.4
	camera.far = 240.0
	add_child(camera)
	apply()


func apply() -> void:
	position = target
	rotation_degrees = Vector3(0, yaw, 0)
	if camera == null:
		return
	camera.size = zoom * ORTHO_SCALE
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
	var view_height := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var speed := zoom * ORTHO_SCALE / view_height
	target += (-right * pixels.x + forward * pixels.y / sin(deg_to_rad(PITCH))) * speed
	target.x = clampf(target.x, -PAN_LIMIT, PAN_LIMIT)
	target.z = clampf(target.z, -PAN_LIMIT + 1.0, 29.0)
	apply()


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	apply()


func turn_quarter(direction: int) -> void:
	yaw = fposmod(yaw + 90.0 * float(direction), 360.0)
	apply()


func focus_on(point: Vector3) -> void:
	target = Vector3(clampf(point.x, -PAN_LIMIT, PAN_LIMIT), 0.0, clampf(point.z, -PAN_LIMIT + 1.0, 29.0))
	apply()


func reset_view() -> void:
	yaw = DEFAULT_YAW
	zoom = DEFAULT_ZOOM
	target = DEFAULT_TARGET
	apply()
