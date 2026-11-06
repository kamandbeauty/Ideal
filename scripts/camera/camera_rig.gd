class_name BattlefieldCamera
extends Node3D

var gun: Artillery
var preview: TrajectoryPreview
var camera: Camera3D
var track_shell: bool = false
var zoomed: bool = false
var projectile: ShellProjectile
var shake_strength: float = 0.0
var _initialized: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 48.0
	camera.near = 0.1
	camera.far = 360.0
	add_child(camera)
	_rng.seed = 1981


func set_projectile(shell: ShellProjectile) -> void:
	projectile = shell


func shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


func toggle_zoom() -> bool:
	zoomed = not zoomed
	return zoomed


func toggle_camera() -> bool:
	track_shell = not track_shell
	return track_shell


func _process(delta: float) -> void:
	if not is_instance_valid(gun):
		return
	var yaw := Basis(Vector3.UP, deg_to_rad(gun.yaw_degrees))
	var desired_position := gun.global_position + yaw * Vector3(0, 9.0, 22.0)
	var aim_point := gun.global_position + yaw * Vector3(0, 1.0, -100.0)
	if is_instance_valid(preview) and preview.has_impact:
		aim_point = preview.impact_position
		aim_point.y = maxf(aim_point.y, 1.0)
	if track_shell and is_instance_valid(projectile) and projectile.active:
		var direction := projectile.velocity.normalized()
		desired_position = projectile.global_position - direction * 11.0 + Vector3.UP * 3.5
		aim_point = projectile.global_position + direction * 12.0
	var blend := 1.0 if not _initialized else 1.0 - exp(-delta * 5.0)
	camera.global_position = camera.global_position.lerp(desired_position, blend)
	if camera.global_position.distance_squared_to(aim_point) > 0.01:
		var look := camera.global_transform.looking_at(aim_point, Vector3.UP)
		camera.quaternion = camera.quaternion.slerp(look.basis.get_rotation_quaternion(), blend)
	camera.fov = lerpf(camera.fov, 29.0 if zoomed else 48.0, 1.0 - exp(-delta * 6.0))
	if shake_strength > 0.001:
		camera.position += (
			Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * shake_strength * 0.16
		)
		shake_strength = move_toward(shake_strength, 0.0, delta * 1.8)
	_initialized = true
