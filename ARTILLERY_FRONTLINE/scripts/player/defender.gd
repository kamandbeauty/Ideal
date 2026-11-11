class_name Defender
extends Node3D
## The gunner: a fixed firing position on the wall. The camera rides on the gun's
## barrel group, so the view follows the aim and nothing else moves the player.

@export var aim_settings: AimSettings

var aim: AimController
var weapon: TwinHmg
var camera: Camera3D
var input_enabled: bool = false
var touch_fire: bool = false
var shake: Vector3 = Vector3.ZERO
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	if aim_settings == null:
		aim_settings = AimSettings.new()
	aim = AimController.new(aim_settings)
	weapon = get_node("Weapon")
	camera = Camera3D.new()
	camera.name = "Eye"
	camera.fov = aim_settings.fov_degrees
	camera.near = 0.08
	camera.far = 700.0
	# The barrel group points along +Z, so "behind the breech" is -Z and the eye turns half a circle to look forward.
	camera.position = Vector3(aim_settings.eye_offset.x, aim_settings.eye_offset.y, -aim_settings.eye_offset.z)
	camera.rotation = Vector3(0.0, PI, 0.0)
	weapon.pivot.add_child(camera)
	camera.make_current()
	weapon.camera = camera
	weapon.shot_fired.connect(_on_shot)
	rng.randomize()
	_apply_aim()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		touch_fire = false
		weapon.set_trigger(false)


## Finger travel on the reference canvas, in pixels.
func add_drag(pixels: Vector2) -> void:
	if input_enabled:
		aim.drag(pixels, Profile.setting("sensitivity"), Profile.setting("invert_y"))


func set_fire(pressed: bool) -> void:
	touch_fire = pressed and input_enabled


func reload() -> void:
	if input_enabled:
		weapon.request_reload()


func _process(delta: float) -> void:
	if input_enabled:
		var turn := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
			turn.x -= 1.0
		if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
			turn.x += 1.0
		if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
			turn.y += 1.0
		if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
			turn.y -= 1.0
		if turn != Vector2.ZERO:
			aim.turn(turn.x * aim_settings.key_turn_speed * delta, turn.y * aim_settings.key_turn_speed * delta)
		weapon.set_trigger(touch_fire or Input.is_physical_key_pressed(KEY_SPACE))
		if Input.is_physical_key_pressed(KEY_R):
			weapon.request_reload()
	aim.step(delta)
	shake = shake.lerp(Vector3.ZERO, 1.0 - exp(-18.0 * delta))
	_apply_aim()


func _apply_aim() -> void:
	weapon.set_aim(aim.aim_yaw(), aim.aim_pitch())
	camera.rotation = Vector3(deg_to_rad(shake.x), PI + deg_to_rad(shake.y), deg_to_rad(shake.z))


func _on_shot(_barrel: int) -> void:
	aim.kick(weapon.data.recoil_scale, rng.randf_range(-1.0, 1.0))
	var amount: float = aim_settings.camera_shake_degrees
	shake += Vector3(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount), rng.randf_range(-amount, amount) * 1.5)


## Adds a jolt from outside the weapon: the gate falling, the wall being struck.
func jolt(degrees: float) -> void:
	shake += Vector3(rng.randf_range(-degrees, degrees), rng.randf_range(-degrees, degrees), rng.randf_range(-degrees, degrees))


func view_direction() -> Vector3:
	return -camera.global_basis.z
