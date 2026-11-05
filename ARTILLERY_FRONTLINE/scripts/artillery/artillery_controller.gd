class_name ArtilleryController
extends Node3D
## Mechanical gun controls only. Supply and economy live in WeaponLoadout.
signal fired(origin: Vector3, direction: Vector3, ammunition: AmmunitionData)
signal reload_started(duration: float)
signal reload_finished
signal aim_changed(yaw: float, elevation: float)
signal state_changed(state: String)

var data: WeaponData
var yaw_degrees: float = 0.0
var elevation_degrees: float = 15.0
var reload_remaining: float = 0.0
var reload_duration: float = 3.4
var reload_animation_time: float = 0.0
var recoil_offset: float = 0.0
var recoil_velocity: float = 0.0
var turret: Node3D
var barrel_pivot: Node3D
var recoil_assembly: Node3D
var muzzle: Marker3D
var breech: Node3D
var loaded: bool = true
var dispersion_seed: int = 7331
var rng := RandomNumberGenerator.new()

func configure(resource: WeaponData) -> void:
	data = resource
	rng.seed = dispersion_seed
	if ResourceLoader.exists(data.model_path):
		var model: Node3D = load(data.model_path).instantiate()
		# Authored Blender front is -Y; glTF import presents it as +Z in Godot.
		model.rotation.y = PI
		add_child(model)
		turret = model.find_child("Turret", true, false) as Node3D
		barrel_pivot = model.find_child("BarrelPivot", true, false) as Node3D
		recoil_assembly = model.find_child("RecoilAssembly", true, false) as Node3D
		var muzzle_node: Node3D = model.find_child("Muzzle", true, false) as Node3D
		breech = model.find_child("BreechBlock", true, false) as Node3D
		if muzzle_node:
			muzzle = Marker3D.new()
			muzzle_node.add_child(muzzle)
	if muzzle == null:
		push_error("Kestrel model is missing its Muzzle transform")
	_update_transforms()

func aim(delta_pixels: Vector2, sensitivity: float = 1.0) -> void:
	adjust(delta_pixels.x * -0.065 * sensitivity, delta_pixels.y * -0.045 * sensitivity)

func adjust(yaw_delta: float, elevation_delta: float) -> void:
	if data == null:
		return
	yaw_degrees = clampf(yaw_degrees + yaw_delta, data.traverse_limits.x, data.traverse_limits.y)
	elevation_degrees = clampf(elevation_degrees + elevation_delta, data.elevation_limits.x, data.elevation_limits.y)
	_update_transforms()
	aim_changed.emit(yaw_degrees, elevation_degrees)

func set_solution(yaw: float, elevation: float) -> bool:
	if data == null or yaw < data.traverse_limits.x or yaw > data.traverse_limits.y or elevation < data.elevation_limits.x or elevation > data.elevation_limits.y:
		return false
	yaw_degrees = yaw
	elevation_degrees = elevation
	_update_transforms()
	aim_changed.emit(yaw_degrees, elevation_degrees)
	return true

func _update_transforms() -> void:
	if turret:
		turret.rotation.y = deg_to_rad(yaw_degrees)
	if barrel_pivot:
		barrel_pivot.rotation.x = -deg_to_rad(elevation_degrees)

func muzzle_position() -> Vector3:
	return muzzle.global_position if muzzle else global_position + Vector3(0, 3, -5)

func aim_direction() -> Vector3:
	return Ballistics.direction(yaw_degrees, elevation_degrees)

func can_fire() -> bool:
	return loaded and reload_remaining <= 0.0 and data != null

func fire(ammunition: AmmunitionData) -> bool:
	if not can_fire() or ammunition == null:
		return false
	var direction: Vector3 = aim_direction()
	var spread: float = deg_to_rad(data.accuracy_degrees)
	direction = direction.rotated(Vector3.UP, rng.randf_range(-spread, spread))
	direction = direction.rotated(Vector3.RIGHT, rng.randf_range(-spread, spread)).normalized()
	var origin: Vector3 = muzzle_position()
	loaded = false
	recoil_velocity = 8.0
	state_changed.emit("FIRED")
	fired.emit(origin, direction, ammunition)
	Events.shot_fired.emit(origin, direction)
	Events.camera_shake_requested.emit(0.28)
	return true

func begin_reload(duration: float) -> bool:
	if loaded or reload_remaining > 0.0:
		return false
	reload_duration = maxf(0.1, duration)
	reload_remaining = reload_duration
	reload_animation_time = 0.0
	reload_started.emit(reload_duration)
	state_changed.emit("RELOADING")
	return true

func tick(delta: float) -> void:
	recoil_velocity += (-recoil_offset * 95.0 - recoil_velocity * 16.0) * delta
	recoil_offset += recoil_velocity * delta
	if recoil_assembly:
		recoil_assembly.position.z = -recoil_offset
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		reload_animation_time += delta
		var phase: float = 1.0 - reload_remaining / reload_duration
		if breech:
			breech.rotation.z = sin(phase * PI) * 1.15
		if reload_remaining <= 0.0:
			loaded = true
			if breech:
				breech.rotation.z = 0.0
			reload_finished.emit()
			state_changed.emit("READY")

func _process(delta: float) -> void:
	tick(delta)
