class_name CoastalWeapon
extends Node3D
## First-person mounted weapon viewmodel. Original GLB assets with a primitive fallback.
signal fired(origin: Vector3, direction: Vector3, weapon_id: String)
signal reload_started(duration: float)
signal reload_finished
signal ammo_changed(current: int, magazine: int)

const WEAPONS: Dictionary = {
	"twin_hmg": {"display": "TWIN .50 HMG", "model": "res://assets/models/mounted_twin_hmg.glb", "interval": 0.085, "damage": 20.0, "magazine": 140, "reload": 2.3, "speed": 430.0, "spread": 0.65, "blast": 0.0, "automatic": true},
	"cannon": {"display": "105MM CANNON", "model": "res://assets/models/mounted_cannon.glb", "interval": 1.15, "damage": 150.0, "magazine": 12, "reload": 3.4, "speed": 260.0, "spread": 0.18, "blast": 5.5, "automatic": false},
	"rocket": {"display": "ROCKET POD", "model": "res://assets/models/mounted_rocket.glb", "interval": 0.72, "damage": 170.0, "magazine": 6, "reload": 3.0, "speed": 115.0, "spread": 0.35, "blast": 9.0, "automatic": false},
	"bazooka": {"display": "M9 BAZOOKA", "model": "res://assets/models/bazooka.glb", "interval": 1.05, "damage": 240.0, "magazine": 4, "reload": 3.2, "speed": 140.0, "spread": 0.25, "blast": 6.5, "automatic": false},
	"autocannon": {"display": "30MM AUTOCANNON", "model": "res://assets/models/mounted_autocannon.glb", "interval": 0.16, "damage": 42.0, "magazine": 70, "reload": 2.7, "speed": 380.0, "spread": 0.45, "blast": 2.2, "automatic": true}
}
const ORDER: Array[String] = ["twin_hmg", "cannon", "rocket", "bazooka", "autocannon"]
const VIEW_OFFSETS: Dictionary = {
	"twin_hmg": Vector3(0.0, -1.58, -1.35),
	"cannon": Vector3(0.0, -1.60, -1.20),
	"rocket": Vector3(0.26, -1.56, -1.10),
	"bazooka": Vector3(0.30, -1.52, -1.05),
	"autocannon": Vector3(0.0, -1.60, -1.18)
}

var weapon_id: String = "twin_hmg"
var ammo: int = 140
var reserve: int = 999
var cooldown: float = 0.0
var reload_remaining: float = 0.0
var heat: float = 0.0
var shots_since_belt: int = 0
var model_root: Node3D
var recoil_node: Node3D
var recoil_rest: Vector3 = Vector3.ZERO
var recoil_nodes: Array[Node3D] = []
var recoil_rests: Array[Vector3] = []
var recoil_offsets: Array[float] = []
var recoil_velocities: Array[float] = []
var breech_node: Node3D
var cover_nodes: Array[Node3D] = []
var ejection_markers: Array[Node3D] = []
var spin_node: Node3D
var muzzles: Array[Node3D] = []
var muzzle_index: int = 0
var recoil_offset: float = 0.0
var recoil_velocity: float = 0.0
var flashes: Array[MeshInstance3D] = []
var flash_timers: Array[float] = []
var flash_light: OmniLight3D
var heat_smoke: GPUParticles3D
var casings: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var ammo_store: Dictionary = {}

func _ready() -> void:
	rng.seed = 88211
	configure("twin_hmg")

func config() -> Dictionary:
	return WEAPONS[weapon_id]

func view_offset() -> Vector3:
	return VIEW_OFFSETS.get(weapon_id, Vector3(0, -1.58, -1.05))

func configure(id: String) -> void:
	if not WEAPONS.has(id):
		return
	if id == weapon_id and model_root != null:
		return
	ammo_store[weapon_id] = ammo
	weapon_id = id
	ammo = int(ammo_store.get(id, int(config().magazine)))
	reload_remaining = 0.0
	cooldown = 0.25
	heat = 0.0
	recoil_offset = 0.0
	recoil_velocity = 0.0
	recoil_offsets.clear()
	recoil_velocities.clear()
	_build_model()
	ammo_changed.emit(ammo, int(config().magazine))

func cycle() -> void:
	var index: int = ORDER.find(weapon_id)
	configure(ORDER[(index + 1) % ORDER.size()])

func select(id: String) -> void:
	configure(id)

func _build_model() -> void:
	if model_root:
		model_root.queue_free()
	model_root = null
	muzzles.clear()
	flashes.clear()
	flash_timers.clear()
	recoil_node = null
	recoil_nodes.clear()
	recoil_rests.clear()
	cover_nodes.clear()
	ejection_markers.clear()
	breech_node = null
	spin_node = null
	if is_instance_valid(flash_light):
		flash_light.queue_free()
	if is_instance_valid(heat_smoke):
		heat_smoke.queue_free()
	var path: String = String(config().model)
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		model_root.rotation.y = PI
		model_root.position = view_offset()
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root, true)
		recoil_node = model_root.find_child("RecoilAssembly", true, false) as Node3D
		for side in ["L", "R"]:
			var independent: Node3D = model_root.find_child("Recoil" + side, true, false) as Node3D
			if independent:
				recoil_nodes.append(independent)
				recoil_rests.append(independent.position)
				recoil_offsets.append(0.0)
				recoil_velocities.append(0.0)
			var cover: Node3D = model_root.find_child("Cover" + side, true, false) as Node3D
			if cover:
				cover_nodes.append(cover)
			var ejection: Node3D = model_root.find_child("Ejection" + side, true, false) as Node3D
			if ejection:
				ejection_markers.append(ejection)
		if recoil_nodes.is_empty() and recoil_node:
			recoil_nodes.append(recoil_node)
			recoil_rests.append(recoil_node.position)
			recoil_offsets.append(0.0)
			recoil_velocities.append(0.0)
		breech_node = model_root.find_child("Breech", true, false) as Node3D
		spin_node = model_root.find_child("BarrelSpin", true, false) as Node3D
		for marker_name in ["MuzzleL", "MuzzleR", "Muzzle"]:
			var marker: Node3D = model_root.find_child(marker_name, true, false) as Node3D
			if marker and not marker in muzzles:
				muzzles.append(marker)
	if model_root == null:
		_build_fallback()
	if recoil_node:
		recoil_rest = recoil_node.position
	if muzzles.is_empty():
		var marker := Marker3D.new()
		marker.name = "MuzzleFallback"
		marker.position = view_offset() + Vector3(0, 0.02, -1.65)
		add_child(marker)
		muzzles.append(marker)
	for muzzle in muzzles:
		var flash := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.34, 0.34) if weapon_id == "twin_hmg" else Vector2(0.7, 0.7)
		flash.mesh = quad
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_color = Color(1.0, 0.82, 0.45, 0.95)
		var flash_texture: Texture2D = MaterialLibrary.texture("muzzle_flash.png")
		if flash_texture:
			material.albedo_texture = flash_texture
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.emission_enabled = true
		material.emission = Color(1.0, 0.55, 0.12)
		material.emission_energy_multiplier = 4.0
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash.material_override = material
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.visible = false
		muzzle.add_child(flash)
		flashes.append(flash)
		flash_timers.append(0.0)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.62, 0.25)
	flash_light.omni_range = 7.0
	flash_light.light_energy = 0.0
	flash_light.position = view_offset() + Vector3(0, 0.0, -1.4)
	add_child(flash_light)
	_build_heat_smoke()

func _build_fallback() -> void:
	model_root = Node3D.new()
	model_root.name = "FallbackWeapon"
	model_root.position = view_offset()
	add_child(model_root)
	MeshFactory.box(model_root, "Receiver", Vector3(0, 0, -0.35), Vector3(0.34, 0.26, 0.95), Color(0.4, 0.44, 0.42), true, "steel")
	MeshFactory.box(model_root, "AmmoBox", Vector3(0.28, -0.16, -0.15), Vector3(0.26, 0.24, 0.42), Color(0.3, 0.34, 0.24), true, "paint_olive")
	var barrel := MeshFactory.cylinder(model_root, "Barrel", Vector3(0, 0.02, -1.15), 0.055, 1.35, Color(0.35, 0.38, 0.36), 18, "steel")
	barrel.rotation.x = PI * 0.5
	var marker := Marker3D.new()
	marker.name = "Muzzle"
	marker.position = Vector3(0, 0.02, -1.85)
	model_root.add_child(marker)
	muzzles.append(marker)
	recoil_node = model_root
	recoil_rest = model_root.position

func _build_heat_smoke() -> void:
	heat_smoke = GPUParticles3D.new()
	heat_smoke.name = "BarrelSmoke"
	heat_smoke.amount = 10
	heat_smoke.lifetime = 1.4
	heat_smoke.emitting = false
	heat_smoke.position = view_offset() + Vector3(0, 0.08, -1.5)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 24.0
	process.initial_velocity_min = 0.4
	process.initial_velocity_max = 1.1
	process.gravity = Vector3(0, 0.8, 0)
	process.scale_min = 0.25
	process.scale_max = 0.6
	process.color = Color(0.55, 0.55, 0.52, 0.22)
	heat_smoke.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	heat_smoke.draw_pass_1 = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.albedo_color = Color(0.6, 0.6, 0.58, 0.25)
	if ExplosionEffect.puff_texture:
		material.albedo_texture = ExplosionEffect.puff_texture
	heat_smoke.material_override = material
	add_child(heat_smoke)

func can_fire() -> bool:
	return cooldown <= 0.0 and reload_remaining <= 0.0 and ammo > 0

func try_fire() -> bool:
	if not can_fire():
		return false
	var data: Dictionary = config()
	ammo -= 1
	cooldown = float(data.interval)
	heat = minf(1.0, heat + (0.045 if weapon_id == "twin_hmg" else 0.11))
	shots_since_belt += 1
	var barrel_index: int = muzzle_index % muzzles.size()
	var muzzle: Node3D = muzzles[barrel_index]
	muzzle_index += 1
	var origin: Vector3 = muzzle.global_position
	# Spread is applied exactly once by the controller, in camera axes, after
	# muzzle-to-crosshair convergence. Keep the raw bore direction here.
	var direction: Vector3 = -global_transform.basis.z
	var kick: float = 5.5 if float(data.blast) > 0.0 else 2.6
	if not recoil_velocities.is_empty():
		recoil_velocities[barrel_index % recoil_velocities.size()] += kick
	else:
		recoil_velocity += kick
	var flash_index: int = (muzzle_index - 1) % flashes.size()
	flashes[flash_index].visible = true
	flashes[flash_index].rotation.z = rng.randf_range(0.0, TAU)
	flashes[flash_index].scale = Vector3.ONE * rng.randf_range(0.8, 1.35)
	flash_timers[flash_index] = 0.045
	flash_light.light_energy = 3.2
	_eject_casing()
	if weapon_id == "twin_hmg":
		Sound.play_at("hmg", origin, -12.0, rng.randf_range(0.92, 1.08))
	elif weapon_id == "rocket" or weapon_id == "bazooka":
		Sound.play_at("rocket", origin, -6.0, rng.randf_range(0.9, 1.05))
	else:
		Sound.play_at("cannon", origin, -9.0, 1.05)
	fired.emit(origin, direction, weapon_id)
	ammo_changed.emit(ammo, int(data.magazine))
	return true

func start_reload() -> bool:
	if reload_remaining > 0.0 or ammo >= int(config().magazine) or reserve <= 0:
		return false
	reload_remaining = float(config().reload)
	reload_started.emit(reload_remaining)
	Sound.play_at("reload", global_position, -8.0)
	return true

func resupply() -> void:
	reserve = 999
	for id in ORDER:
		ammo_store[id] = int(WEAPONS[id].magazine)
	ammo = int(config().magazine)
	reload_remaining = 0.0
	ammo_changed.emit(ammo, int(config().magazine))

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	heat = maxf(0.0, heat - delta * 0.08)
	if heat_smoke:
		heat_smoke.emitting = heat > 0.55
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		var open_amount: float = sin((1.0 - reload_remaining / float(config().reload)) * PI)
		if breech_node:
			breech_node.rotation.x = open_amount * 0.45
		for cover in cover_nodes:
			cover.rotation.x = -open_amount * 0.85
		if reload_remaining <= 0.0:
			var needed: int = int(config().magazine) - ammo
			var taken: int = mini(needed, reserve)
			ammo += taken
			reserve -= taken
			ammo_store[weapon_id] = ammo
			if breech_node:
				breech_node.rotation.x = 0.0
			for cover in cover_nodes:
				cover.rotation.x = 0.0
			reload_finished.emit()
			ammo_changed.emit(ammo, int(config().magazine))
	for index in range(recoil_nodes.size()):
		recoil_velocities[index] += (-recoil_offsets[index] * 120.0 - recoil_velocities[index] * 18.0) * delta
		recoil_offsets[index] += recoil_velocities[index] * delta
		recoil_nodes[index].position = recoil_rests[index] + Vector3(0, 0, -recoil_offsets[index] * 0.08)
	if recoil_nodes.is_empty():
		recoil_velocity += (-recoil_offset * 120.0 - recoil_velocity * 18.0) * delta
		recoil_offset += recoil_velocity * delta
		if recoil_node:
			recoil_node.position = recoil_rest + Vector3(0, 0, -recoil_offset * 0.08)
	# Twin barrels are fixed; only the centered autocannon shroud may spin.
	if spin_node and weapon_id == "autocannon":
		spin_node.rotation.z += delta * (2.0 + heat * 10.0)
	if flash_light:
		flash_light.light_energy = maxf(0.0, flash_light.light_energy - delta * 42.0)
	for index in range(flash_timers.size()):
		if flash_timers[index] > 0.0:
			flash_timers[index] -= delta
			if flash_timers[index] <= 0.0:
				flashes[index].visible = false
	_tick_casings(delta)

func screen_bounds(active_camera: Camera3D) -> Rect2:
	var result := Rect2()
	var first: bool = true
	if model_root == null:
		return result
	for child in model_root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		if instance.mesh == null:
			continue
		var aabb: AABB = instance.mesh.get_aabb()
		for corner in [Vector3(aabb.position.x, aabb.position.y, aabb.position.z), Vector3((aabb.position + aabb.size).x, aabb.position.y, aabb.position.z), Vector3(aabb.position.x, (aabb.position + aabb.size).y, aabb.position.z), Vector3(aabb.position.x, aabb.position.y, (aabb.position + aabb.size).z), Vector3((aabb.position + aabb.size).x, (aabb.position + aabb.size).y, aabb.position.z), Vector3((aabb.position + aabb.size).x, aabb.position.y, (aabb.position + aabb.size).z), Vector3(aabb.position.x, (aabb.position + aabb.size).y, (aabb.position + aabb.size).z), (aabb.position + aabb.size)]:
			var screen: Vector2 = active_camera.unproject_position(instance.global_transform * corner)
			if first:
				result = Rect2(screen, Vector2.ZERO)
				first = false
			else:
				result = result.expand(screen)
	return result

func _eject_casing() -> void:
	if weapon_id == "rocket" or weapon_id == "bazooka":
		return
	if casings.size() > 22:
		var old: Dictionary = casings.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()
	var casing := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012 if weapon_id == "twin_hmg" else 0.03
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.09 if weapon_id == "twin_hmg" else 0.2
	mesh.radial_segments = 10
	casing.mesh = mesh
	casing.material_override = MaterialLibrary.weapon_surface("weapon_brass", Color.WHITE, true)
	casing.top_level = true
	var casing_parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	casing_parent.add_child(casing)
	var eject_index: int = (muzzle_index - 1) % maxi(ejection_markers.size(), 1)
	if not ejection_markers.is_empty():
		casing.global_position = ejection_markers[eject_index].global_position
	else:
		casing.global_position = global_position + global_transform.basis.x * 0.22 + Vector3.UP * -0.05
	casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casings.append({"node": casing, "velocity": global_transform.basis.x * rng.randf_range(1.4, 2.6) + Vector3.UP * rng.randf_range(1.2, 2.2), "age": 0.0})

func _tick_casings(delta: float) -> void:
	for index in range(casings.size() - 1, -1, -1):
		var entry: Dictionary = casings[index]
		var node: MeshInstance3D = entry.node
		if not is_instance_valid(node):
			casings.remove_at(index)
			continue
		entry.age += delta
		entry.velocity.y -= 9.81 * delta
		node.global_position += entry.velocity * delta
		node.rotation += Vector3(4.0, 6.0, 3.0) * delta
		if entry.age > 1.3:
			node.queue_free()
			casings.remove_at(index)
