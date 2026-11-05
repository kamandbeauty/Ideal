class_name ArtilleryCameraRig
extends Node3D

enum Mode { GUN, OPTIC, SHELL, IMPACT }
var camera: Camera3D
var controller: ArtilleryController
var projectiles: ProjectilePool
var targeting: TargetingSystem
var mode: Mode = Mode.GUN
var previous_mode: Mode = Mode.GUN
var focus: Vector3 = Vector3.ZERO
var trauma: float = 0.0
var clock: float = 0.0
var impact_point: Vector3 = Vector3.ZERO
var impact_timer: float = 0.0
var initialized: bool = false
var zoomed: bool = false

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.near = 0.12
	camera.far = 1600.0
	camera.fov = 57.0
	camera.current = true
	add_child(camera)
	Events.camera_shake_requested.connect(shake)
	Events.projectile_impacted.connect(_on_impact)

func shake(strength: float) -> void:
	if Profile.data.settings.camera_shake:
		trauma = minf(0.65, trauma + strength)

func cycle() -> void:
	match mode:
		Mode.GUN: mode = Mode.OPTIC
		Mode.OPTIC: mode = Mode.SHELL
		_: mode = Mode.GUN
	previous_mode = mode
	impact_timer = 0.0

func toggle_zoom() -> void:
	if mode == Mode.OPTIC:
		zoomed = not zoomed
	else:
		mode = Mode.OPTIC
		zoomed = true
	previous_mode = mode

func _on_impact(point: Vector3, _normal: Vector3, _direct: bool) -> void:
	var distance: float = camera.global_position.distance_to(point) if camera else 500.0
	trauma = minf(0.5, trauma + 0.16 * clampf(100.0 / maxf(distance, 1.0), 0.0, 1.0)) if Profile.data.settings.camera_shake else 0.0
	if mode == Mode.SHELL:
		impact_point = point
		previous_mode = Mode.GUN
		mode = Mode.IMPACT
		impact_timer = 1.8

func _process(delta: float) -> void:
	if controller == null or camera == null:
		return
	clock += delta
	var desired_position: Vector3 = controller.global_position + Vector3(11, 8.0, 18)
	var desired_focus: Vector3 = controller.global_position + Vector3(0, 2.5, -38)
	var desired_fov: float = 57.0
	match mode:
		Mode.GUN:
			desired_position = controller.global_position + Vector3(11, 8.0, 18).rotated(Vector3.UP, deg_to_rad(controller.yaw_degrees * 0.3))
			desired_focus = controller.global_position + Ballistics.direction(controller.yaw_degrees * 0.65, 0) * 42.0 + Vector3.UP * 2.0
		Mode.OPTIC:
			desired_position = controller.global_position + Vector3(0, 14.0, 8.0)
			desired_focus = targeting.predicted_impact if targeting and targeting.prediction_valid else controller.global_position + controller.aim_direction() * 350.0
			desired_fov = 23.0 if zoomed else 39.0
		Mode.SHELL:
			if projectiles and projectiles.active_shell and projectiles.active_shell.active:
				var shell: ArtilleryProjectile = projectiles.active_shell
				desired_position = shell.global_position + Vector3(12, 7, 23)
				desired_focus = shell.global_position + shell.velocity.normalized() * 7.0
				desired_fov = 56.0
			else:
				desired_position = controller.global_position + Vector3(11, 8, 18)
		Mode.IMPACT:
			impact_timer -= delta
			desired_position = impact_point + Vector3(22, 14, 30)
			desired_focus = impact_point + Vector3.UP * 2.0
			desired_fov = 52.0
			if impact_timer <= 0.0:
				mode = previous_mode
	if not initialized:
		camera.global_position = desired_position
		focus = desired_focus
		initialized = true
	var weight: float = 1.0 - exp(-delta * (8.0 if mode == Mode.SHELL else 4.5))
	camera.global_position = camera.global_position.lerp(desired_position, weight)
	focus = focus.lerp(desired_focus, weight)
	if camera.global_position.distance_squared_to(focus) > 0.01:
		camera.look_at(focus, Vector3.UP)
	camera.fov = lerpf(camera.fov, desired_fov, weight)
	trauma = maxf(0.0, trauma - delta * 1.25)
	var amplitude: float = trauma * trauma * 0.5
	camera.h_offset = sin(clock * 61.0) * amplitude
	camera.v_offset = cos(clock * 47.0) * amplitude * 0.65

func mode_name() -> String:
	return ["GUN", "OPTIC", "SHELL", "IMPACT"][int(mode)]
