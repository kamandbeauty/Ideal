class_name Weapon
extends Node3D
## What every weapon of the gunner shares: its numbers and ammunition, the
## trigger, the sight line, and being raised or put away when the player
## switches. A weapon keeps reloading while it is put away.

signal shot_fired(barrel: int)

@export var data: WeaponData

var state: WeaponState
## The gunner's eye and the frame that carries it. Rounds start at the muzzle
## but converge on what this sight line rests on.
var camera: Camera3D
var sight: Node3D
var bullets: BulletPool
var rockets: RocketPool
var effects: EffectPool
var trigger: bool = false
var selected: bool = false
## 0 = put away, 1 = up and ready to fire.
var readiness: float = 0.0
var raise_delay: float = 0.0
var since_shot: float = 10.0
var dry_cooldown: float = 0.0
var rng := RandomNumberGenerator.new()
var sight_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	if data == null:
		data = WeaponData.new()
	state = WeaponState.new(data)
	state.reload_started.connect(_on_reload_started)
	state.reload_finished.connect(_on_reload_finished)
	rng.randomize()
	sight_query.collision_mask = Layers.BULLET_MASK
	sight_query.collide_with_areas = true
	_build()
	_pose()


# -- For the concrete weapon -------------------------------------------------------
## Finds the model's parts and builds its effects.
func _build() -> void:
	pass


## Sharpens the gun metal so the kit reads as machined steel, not a smooth toy.
func _enrich_surfaces(root: Node) -> void:
	if root == null:
		return
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		if mesh.mesh == null:
			continue
		for index: int in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(index)
			if source == null or not (source is StandardMaterial3D):
				continue
			var dressed: StandardMaterial3D = (source as StandardMaterial3D).duplicate()
			var n: String = dressed.resource_name.to_lower()
			if n.contains("bore") or n.contains("black"):
				dressed.albedo_color = Color(0.015, 0.016, 0.018)
				dressed.roughness = 0.92
				dressed.metallic = 0.15
			elif n.contains("olive"):
				dressed.albedo_color = Color(0.12, 0.14, 0.09)
				dressed.roughness = 0.58
				dressed.metallic = 0.22
			elif n.contains("grip") or n.contains("wood"):
				dressed.roughness = 0.94
				dressed.metallic = 0.0
			elif n.contains("brass"):
				dressed.albedo_color = Color(0.62, 0.48, 0.18)
				dressed.metallic = 0.85
				dressed.roughness = 0.38
			else:
				dressed.metallic = maxf(dressed.metallic, 0.84)
				dressed.roughness = clampf(dressed.roughness * 0.7, 0.26, 0.5)
				dressed.metallic_specular = 0.72
			dressed.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mesh.set_surface_override_material(index, dressed)


func _kit_box(parent: Node3D, at: Vector3, size: Vector3, color: Color, metal: float = 0.85, rough: float = 0.4) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	mat.metallic_specular = 0.65
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


## Places the model for the current readiness, recoil and reload.
func _pose() -> void:
	pass


## Launches one round; ammunition has already been taken.
func _fire_round() -> void:
	pass


## Per-frame animation.
func _animate(_delta: float) -> void:
	pass


## Per-tick logic of the concrete weapon, run before any round is released.
func _tick(_delta: float) -> void:
	pass


## Whether a round may leave now that the trigger is held and the weapon is up.
## A gun that has to run up to speed says no until it has.
func _may_fire() -> bool:
	return true


## Yaw is positive to the right, pitch positive upward, both in degrees.
func set_aim(_yaw_degrees: float, _pitch_degrees: float) -> void:
	pass


# -- Handling ----------------------------------------------------------------------
## Brings the weapon up; `delay` lets the previous one get out of the way first.
func select(delay: float = 0.0, instant: bool = false) -> void:
	selected = true
	raise_delay = 0.0 if instant else delay
	if instant:
		readiness = 1.0
	_pose()


func deselect(instant: bool = false) -> void:
	selected = false
	trigger = false
	if instant:
		readiness = 0.0
	_pose()


func is_ready() -> bool:
	return selected and readiness >= 1.0


func set_trigger(pressed: bool) -> void:
	trigger = pressed


func request_reload() -> bool:
	return selected and state.start_reload()


## Unit vector along the sight line, in world space.
func aim_direction() -> Vector3:
	if sight != null:
		return -sight.global_basis.z.normalized()
	return -global_basis.z.normalized()


func bore_direction() -> Vector3:
	return aim_direction()


## The point the crosshair rests on, so every round goes where the player is looking.
func sight_point() -> Vector3:
	var forward: Vector3 = aim_direction()
	if camera == null or not is_inside_tree():
		return global_position + forward * 200.0
	var from: Vector3 = camera.global_position
	sight_query.from = from
	sight_query.to = from + forward * data.max_range
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(sight_query)
	var distance: float = 200.0
	if not hit.is_empty():
		distance = from.distance_to(hit.position)
	return from + forward * maxf(distance, data.min_convergence)


func scatter(direction: Vector3) -> Vector3:
	if data.spread_degrees <= 0.0:
		return direction
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up: Vector3 = side.cross(direction)
	var radius: float = tan(deg_to_rad(data.spread_degrees)) * sqrt(rng.randf())
	var angle: float = rng.randf() * TAU
	return (direction + (side * cos(angle) + up * sin(angle)) * radius).normalized()


func _physics_process(delta: float) -> void:
	state.step(delta)
	since_shot += delta
	dry_cooldown = maxf(0.0, dry_cooldown - delta)
	if selected:
		if raise_delay > 0.0:
			raise_delay -= delta
		else:
			readiness = minf(1.0, readiness + delta / data.raise_time)
	else:
		readiness = maxf(0.0, readiness - delta / data.lower_time)
	_tick(delta)
	if not trigger or not is_ready():
		return
	var guard: int = 4 if _may_fire() else 0
	while guard > 0 and state.try_fire():
		guard -= 1
		since_shot = 0.0
		_fire_round()
		Events.weapon_fired.emit(self)
		Events.ammo_changed.emit(state.ammo, data.magazine_size)
	if (state.reloading or state.ammo <= 0) and since_shot > 0.2 and dry_cooldown <= 0.0:
		dry_cooldown = 0.45
		Sound.play("dry_fire", -8.0)


func _process(delta: float) -> void:
	_animate(delta)
	_pose()


func _on_reload_started(duration: float) -> void:
	if selected:
		Sound.play("reload", -3.0)
		Events.reload_started.emit(duration)


func _on_reload_finished() -> void:
	if selected:
		Events.reload_finished.emit()
		Events.ammo_changed.emit(state.ammo, data.magazine_size)
