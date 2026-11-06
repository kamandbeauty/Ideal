class_name Artillery
extends Node3D

signal aim_changed
signal fired(origin: Vector3, velocity: Vector3, ammo: AmmoConfig)
signal feedback(message: String)
signal reload_started

var config: WeaponConfig
var ammo_types: Array[AmmoConfig] = []
var state := WeaponState.new()
var yaw_degrees: float = 0.0
var elevation_degrees: float = 26.0
var sensitivity: float = 1.0

var _turret: Node3D
var _barrel_pivot: Node3D
var _barrel_visual: Node3D
var _muzzle: Marker3D
var _flash: OmniLight3D
var _muzzle_flash: MeshInstance3D
var _recoil_tween: Tween


func _ready() -> void:
	assert(config != null and not ammo_types.is_empty())
	state.setup(config, ammo_types)
	state.reload_started.connect(_on_reload_started)
	_build_model()
	_update_aim()


func aim_by_pixels(relative: Vector2) -> void:
	yaw_degrees = clampf(
		yaw_degrees - relative.x * 0.12 * sensitivity,
		-config.traverse_degrees,
		config.traverse_degrees
	)
	elevation_degrees = clampf(
		elevation_degrees - relative.y * 0.09 * sensitivity,
		config.min_elevation_degrees,
		config.max_elevation_degrees
	)
	_update_aim()
	aim_changed.emit()


func set_aim(yaw: float, elevation: float) -> void:
	yaw_degrees = clampf(yaw, -config.traverse_degrees, config.traverse_degrees)
	elevation_degrees = clampf(
		elevation, config.min_elevation_degrees, config.max_elevation_degrees
	)
	_update_aim()
	aim_changed.emit()


func muzzle_position() -> Vector3:
	return _muzzle.global_position


func launch_velocity() -> Vector3:
	return (
		-_barrel_pivot.global_basis.z.normalized()
		* config.muzzle_velocity
		* state.current_ammo().velocity_multiplier
	)


func try_fire() -> bool:
	if not state.fire():
		if state.reload_remaining > 0.0:
			feedback.emit("LOADING ROUND")
		elif state.current_rounds() <= 0:
			feedback.emit("NO ROUNDS — SELECT ANOTHER TYPE")
		else:
			feedback.emit("RELOAD TO FIRE")
		return false
	var origin := muzzle_position()
	var velocity := launch_velocity()
	fired.emit(origin, velocity, state.current_ammo())
	_play_recoil()
	return true


func reload_weapon() -> void:
	if not state.request_reload():
		if state.chambered:
			feedback.emit("ROUND CHAMBERED")
		elif state.current_rounds() <= 0:
			feedback.emit("NO ROUNDS — SELECT ANOTHER TYPE")


func select_ammo(index: int) -> void:
	if state.select_ammo(index):
		feedback.emit("AMMO CHANGED — RELOAD")
		aim_changed.emit()


func _physics_process(delta: float) -> void:
	state.advance(delta)


func _update_aim() -> void:
	if _turret == null:
		return
	_turret.rotation.y = deg_to_rad(yaw_degrees)
	_barrel_pivot.rotation.x = deg_to_rad(elevation_degrees)


func _on_reload_started() -> void:
	reload_started.emit()
	# The breech moves subtly while a round is being chambered.
	if _barrel_visual != null:
		var tween := create_tween()
		tween.tween_property(_barrel_visual, "position:z", 0.28, config.reload_seconds * 0.45)
		tween.tween_property(_barrel_visual, "position:z", 0.0, config.reload_seconds * 0.55)


func _play_recoil() -> void:
	if is_instance_valid(_recoil_tween):
		_recoil_tween.kill()
	_barrel_visual.position.z = 0.0
	_flash.light_energy = 7.0
	_muzzle_flash.visible = true
	_muzzle_flash.scale = Vector3(0.2, 0.2, 0.2)
	_recoil_tween = create_tween().set_parallel(true)
	(
		_recoil_tween
		. tween_property(_barrel_visual, "position:z", 1.1, 0.08)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_recoil_tween.tween_property(_flash, "light_energy", 0.0, 0.22)
	_recoil_tween.tween_property(_muzzle_flash, "scale", Vector3(2.4, 2.4, 3.8), 0.16)
	_recoil_tween.tween_callback(func() -> void: _muzzle_flash.visible = false).set_delay(0.18)
	(
		_recoil_tween
		. chain()
		. tween_property(_barrel_visual, "position:z", 0.0, 0.65)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


func _build_model() -> void:
	var hull := ShapeFactory.material(Color("505e49"), 0.32, 0.83)
	var armor := ShapeFactory.material(Color("738068"), 0.25, 0.85)
	var edge := ShapeFactory.material(Color("2e3931"), 0.4, 0.75)
	var rubber := ShapeFactory.material(Color("242a26"), 0.0, 1.0)
	var brass := ShapeFactory.material(Color("d0a756"), 0.5, 0.55)
	# Lower hull and broad tracks.
	ShapeFactory.box(self, Vector3(4.8, 1.15, 7.2), Vector3(0, 1.0, 0.0), hull)
	ShapeFactory.box(self, Vector3(4.0, 0.42, 5.7), Vector3(0, 1.76, 0.0), edge)
	for side in [-1.0, 1.0]:
		ShapeFactory.box(self, Vector3(1.3, 1.2, 7.5), Vector3(side * 2.35, 0.7, 0), rubber)
		ShapeFactory.box(self, Vector3(1.45, 0.25, 7.2), Vector3(side * 2.35, 1.34, 0), armor)
		for z in [-2.7, -1.6, -0.5, 0.6, 1.7, 2.8]:
			var wheel := ShapeFactory.cylinder(
				self, 0.55, 0.22, Vector3(side * 3.02, 0.64, z), edge, 10
			)
			wheel.rotation_degrees.z = 90
			var hub := ShapeFactory.cylinder(
				self, 0.22, 0.24, Vector3(side * 3.14, 0.64, z), armor, 8
			)
			hub.rotation_degrees.z = 90
		for z in [-3.4, -2.4, -1.4, -0.4, 0.6, 1.6, 2.6, 3.4]:
			ShapeFactory.box(self, Vector3(1.45, 0.1, 0.12), Vector3(side * 2.35, 1.48, z), edge)
	# Turret and gun are independent axes.
	_turret = Node3D.new()
	_turret.position = Vector3(0, 1.98, 0.2)
	add_child(_turret)
	ShapeFactory.cylinder(_turret, 1.85, 0.38, Vector3(0, 0.1, 0), edge, 16)
	ShapeFactory.box(_turret, Vector3(3.5, 1.25, 3.5), Vector3(0, 0.84, 0.35), armor)
	ShapeFactory.box(_turret, Vector3(3.0, 0.22, 3.0), Vector3(0, 1.52, 0.3), hull)
	ShapeFactory.box(_turret, Vector3(0.75, 0.4, 0.8), Vector3(1.05, 1.78, 0.65), edge)
	ShapeFactory.cylinder(_turret, 0.55, 0.15, Vector3(-0.75, 1.67, 0.4), edge, 12)
	ShapeFactory.box(_turret, Vector3(0.13, 1.6, 0.13), Vector3(1.3, 2.28, 1.1), edge)
	_barrel_pivot = Node3D.new()
	_barrel_pivot.position = Vector3(0, 0.95, -1.25)
	_turret.add_child(_barrel_pivot)
	_barrel_visual = Node3D.new()
	_barrel_pivot.add_child(_barrel_visual)
	ShapeFactory.box(_barrel_visual, Vector3(1.15, 1.0, 1.35), Vector3(0, 0, -0.25), edge)
	var barrel := ShapeFactory.cylinder(_barrel_visual, 0.42, 5.5, Vector3(0, 0, -3.0), hull, 14)
	barrel.rotation_degrees.x = 90
	var sleeve := ShapeFactory.cylinder(_barrel_visual, 0.53, 1.7, Vector3(0, 0, -1.4), armor, 14)
	sleeve.rotation_degrees.x = 90
	var muzzle_brake := ShapeFactory.cylinder(
		_barrel_visual, 0.58, 0.8, Vector3(0, 0, -5.8), edge, 12
	)
	muzzle_brake.rotation_degrees.x = 90
	var band := ShapeFactory.cylinder(_barrel_visual, 0.45, 0.13, Vector3(0, 0, -5.0), brass, 12)
	band.rotation_degrees.x = 90
	_muzzle = Marker3D.new()
	_muzzle.position = Vector3(0, 0, -6.25)
	_barrel_pivot.add_child(_muzzle)
	var flash_material := ShapeFactory.material(Color("ffd06b"))
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.emission_enabled = true
	flash_material.emission = Color("ff9b36")
	_muzzle_flash = ShapeFactory.sphere(
		_barrel_pivot, Vector3.ONE, Vector3(0, 0, -6.4), flash_material, 10
	)
	_muzzle_flash.visible = false
	_flash = OmniLight3D.new()
	_flash.position = Vector3(0, 0, -6.25)
	_flash.light_color = Color("ffba5c")
	_flash.omni_range = 18.0
	_flash.light_energy = 0.0
	_barrel_pivot.add_child(_flash)
