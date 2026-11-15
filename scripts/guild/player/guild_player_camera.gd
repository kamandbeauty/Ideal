class_name GuildPlayerCamera
extends Node3D
## The isometric-ish follow camera: a pivot that trails the player, a spring arm
## that keeps the walls out of the lens, and a camera locked to a 36° pitch.
##
## Orbit is free in yaw (a full 360°) and clamped in pitch, zoom is clamped
## between 9 m and 20 m, and pinch/drag are plain function calls so the touch HUD
## and the smoke test drive exactly the same code.

const DEFAULT_PITCH := 36.0
const MIN_PITCH := 16.0
const MAX_PITCH := 62.0
const MIN_DISTANCE := 9.0
const MAX_DISTANCE := 20.0
const DEFAULT_DISTANCE := 12.5
const DEFAULT_YAW := 24.0
const FOLLOW_DAMPING := 8.0
const TURN_STEP := 45.0
const ZOOM_STEP := 0.86

var yaw := DEFAULT_YAW
var pitch := DEFAULT_PITCH
var distance := DEFAULT_DISTANCE
var target := Vector3.ZERO

var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D

var _look_at := Vector3.ZERO


func _ready() -> void:
	if pivot == null:
		_build()


func _build() -> void:
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)

	arm = SpringArm3D.new()
	arm.name = "Arm"
	arm.spring_length = distance
	arm.margin = 0.3
	arm.collision_mask = 1
	pivot.add_child(arm)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 52.0
	camera.near = 0.15
	camera.far = 260.0
	arm.add_child(camera)

	_look_at = target
	_sync()


## Where the camera wants to be, before the spring arm resolves collisions.
func desired_position() -> Vector3:
	var orbit_basis := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0.0))
	return target + orbit_basis * Vector3(0.0, 0.0, distance)


func orbit(delta_yaw: float, delta_pitch: float) -> void:
	yaw = wrapf(yaw + delta_yaw, -180.0, 180.0)
	pitch = clampf(pitch + delta_pitch, MIN_PITCH, MAX_PITCH)
	_sync()


func turn_quarter(direction: int) -> void:
	orbit(TURN_STEP * direction, 0.0)


func zoom_by(factor: float) -> void:
	distance = clampf(distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	_sync()


## Pinch zoom from touch: `start` is the distance when the two fingers landed and
## `ratio` is the change in finger separation (1.4 = fingers moved 40% apart).
func pinch(start: float, ratio: float) -> void:
	distance = clampf(start / maxf(ratio, 0.1), MIN_DISTANCE, MAX_DISTANCE)
	_sync()


func focus_on(point: Vector3) -> void:
	target = point
	_look_at = point
	_sync()


func reset_view() -> void:
	yaw = DEFAULT_YAW
	pitch = DEFAULT_PITCH
	distance = DEFAULT_DISTANCE
	_sync()


## Trails the player smoothly; call every frame with the player's feet position.
func follow_feet(feet: Vector3, delta: float, height: float = 1.25) -> void:
	var wanted := feet + Vector3(0.0, height, 0.0)
	var weight := minf(1.0, delta * FOLLOW_DAMPING)
	_look_at = _look_at.lerp(wanted, weight)
	target = _look_at
	pivot.position = _look_at
	_sync()


func _sync() -> void:
	if pivot == null:
		return
	pivot.position = target
	if arm != null:
		arm.rotation = Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0.0)
		arm.spring_length = distance
