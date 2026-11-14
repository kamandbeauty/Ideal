class_name CityCamera
extends Node3D
## Orbit camera over the island: pan, zoom and quarter turns, all smoothed.

const MIN_ZOOM := 11.0
const MAX_ZOOM := 44.0
const PITCH := 55.0
const PAN_LIMIT := 13.0
const ZOOM_SPEED := 8.0
const TURN_SPEED := 7.0
const PAN_SPEED := 10.0
const PIXELS_TO_TILES := 0.0011

var camera: Camera3D
var zoom := 26.0
var target_zoom := 26.0
var yaw := deg_to_rad(35.0)
var target_yaw := deg_to_rad(35.0)
var focus := Vector3.ZERO
var target_focus := Vector3.ZERO


func setup() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 46.0
	camera.near = 0.5
	camera.far = 320.0
	camera.current = true
	add_child(camera)
	_apply()


func _process(delta: float) -> void:
	zoom = lerpf(zoom, target_zoom, minf(1.0, delta * ZOOM_SPEED))
	yaw = lerp_angle(yaw, target_yaw, minf(1.0, delta * TURN_SPEED))
	focus = focus.lerp(target_focus, minf(1.0, delta * PAN_SPEED))
	_apply()


## Drag the world with the finger.
func pan_by_pixels(screen_delta: Vector2) -> void:
	var factor := zoom * PIXELS_TO_TILES
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	target_focus += (-right * screen_delta.x + forward * screen_delta.y) * factor
	target_focus.x = clampf(target_focus.x, -PAN_LIMIT, PAN_LIMIT)
	target_focus.z = clampf(target_focus.z, -PAN_LIMIT, PAN_LIMIT)


func zoom_by(factor: float) -> void:
	target_zoom = clampf(target_zoom * factor, MIN_ZOOM, MAX_ZOOM)


func turn_quarter() -> void:
	target_yaw += PI / 2.0


func reset_view() -> void:
	target_focus = Vector3.ZERO


func _apply() -> void:
	position = focus
	rotation = Vector3(deg_to_rad(-PITCH), yaw, 0.0)
	if camera != null:
		camera.position = Vector3(0.0, 0.0, zoom)
