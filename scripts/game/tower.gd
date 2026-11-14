class_name Tower
extends StaticBody3D
## A built tower. Finds a target in range, aims and fires.

var kind: String = "sentry"
var level := 1
var battle

var _cooldown := 0.0
var _turret: Node3D
var _range_ring: MeshInstance3D
var _pips: Array[MeshInstance3D] = []
var _spin: Node3D


func setup(tower_kind: String, battle_ref) -> void:
	kind = tower_kind
	battle = battle_ref
	collision_layer = 2
	collision_mask = 0
	add_to_group("towers")
	_build_collision()
	_build_visuals()
	_apply_level()


func get_range() -> float:
	return TowerData.range_for(kind, level)


func set_level(next_level: int) -> void:
	level = clampi(next_level, 1, TowerData.max_level(kind))
	_apply_level()


func show_range(visible_range: bool) -> void:
	if _range_ring != null:
		_range_ring.visible = visible_range
		_range_ring.scale = Vector3(get_range(), 1.0, get_range())


func _physics_process(delta: float) -> void:
	if battle == null:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := battle.find_target(global_position, get_range()) as Enemy
	if target == null:
		return
	_cooldown = TowerData.cooldown_for(kind, level)
	_aim_at(target.global_position)
	_fire(target)


func _aim_at(point: Vector3) -> void:
	if _turret == null:
		return
	var flat_target := Vector3(point.x, _turret.global_position.y, point.z)
	if _turret.global_position.distance_to(flat_target) < 0.05:
		return
	_turret.look_at(flat_target, Vector3.UP)


func _fire(target: Enemy) -> void:
	if kind == "frost":
		battle.apply_area_damage(
			global_position,
			get_range(),
			TowerData.damage_for(kind, level),
			TowerData.slow_for(kind, level),
			TowerData.slow_time_for(kind, level),
			TowerData.color(kind)
		)
		battle.spawn_ring(global_position, get_range(), TowerData.color(kind))
	else:
		battle.launch_shot(global_position + Vector3(0.0, 1.5, 0.0), target, kind, level)


func _apply_level() -> void:
	var color := TowerData.color(kind)
	for i in _pips.size():
		var pip := _pips[i]
		var on := i < level
		pip.visible = true
		var material := pip.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = color if on else Color(0.2, 0.24, 0.3)
			material.emission_enabled = on
			material.emission_energy_multiplier = 1.6 if on else 0.0
	scale = Vector3.ONE * (1.0 + 0.07 * (level - 1))


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.95
	cylinder.height = 2.4
	shape.shape = cylinder
	shape.position.y = 1.2
	add_child(shape)


func _build_visuals() -> void:
	var color := TowerData.color(kind)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.78
	base_mesh.bottom_radius = 0.92
	base_mesh.height = 0.5
	base.mesh = base_mesh
	base.position.y = 0.25
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.24, 0.29, 0.36)
	base_material.roughness = 0.9
	base.material_override = base_material
	add_child(base)

	var column := MeshInstance3D.new()
	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.32
	column_mesh.bottom_radius = 0.4
	column_mesh.height = 0.9
	column.mesh = column_mesh
	column.position.y = 0.9
	var column_material := StandardMaterial3D.new()
	column_material.albedo_color = color.darkened(0.35)
	column_material.roughness = 0.7
	column.material_override = column_material
	add_child(column)

	_turret = Node3D.new()
	_turret.name = "Turret"
	_turret.position.y = 1.5
	add_child(_turret)

	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = color
	head_material.roughness = 0.45
	head_material.metallic = 0.2

	var barrel_material := StandardMaterial3D.new()
	barrel_material.albedo_color = color.lightened(0.35)
	barrel_material.roughness = 0.35
	barrel_material.metallic = 0.5

	match kind:
		"sentry":
			var head := MeshInstance3D.new()
			var head_mesh := BoxMesh.new()
			head_mesh.size = Vector3(0.56, 0.42, 0.7)
			head.mesh = head_mesh
			head.material_override = head_material
			_turret.add_child(head)
			for side in [-0.16, 0.16]:
				var barrel := MeshInstance3D.new()
				var barrel_mesh := CylinderMesh.new()
				barrel_mesh.top_radius = 0.06
				barrel_mesh.bottom_radius = 0.07
				barrel_mesh.height = 0.8
				barrel.mesh = barrel_mesh
				barrel.material_override = barrel_material
				barrel.rotation_degrees = Vector3(90, 0, 0)
				barrel.position = Vector3(side, 0.02, -0.45)
				_turret.add_child(barrel)
		"cannon":
			var head := MeshInstance3D.new()
			var head_mesh := SphereMesh.new()
			head_mesh.radius = 0.42
			head_mesh.height = 0.7
			head.mesh = head_mesh
			head.material_override = head_material
			_turret.add_child(head)
			var barrel := MeshInstance3D.new()
			var barrel_mesh := CylinderMesh.new()
			barrel_mesh.top_radius = 0.17
			barrel_mesh.bottom_radius = 0.22
			barrel_mesh.height = 1.25
			barrel.mesh = barrel_mesh
			barrel.material_override = barrel_material
			barrel.rotation_degrees = Vector3(90, 0, 0)
			barrel.position = Vector3(0.0, 0.0, -0.62)
			_turret.add_child(barrel)
		"frost":
			_spin = Node3D.new()
			_spin.name = "Spin"
			_turret.add_child(_spin)
			var crystal := MeshInstance3D.new()
			var crystal_mesh := PrismMesh.new()
			crystal_mesh.size = Vector3(0.5, 1.0, 0.5)
			crystal.mesh = crystal_mesh
			var crystal_material := StandardMaterial3D.new()
			crystal_material.albedo_color = color
			crystal_material.emission_enabled = true
			crystal_material.emission = color
			crystal_material.emission_energy_multiplier = 0.9
			crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			crystal_material.albedo_color.a = 0.9
			crystal.material_override = crystal_material
			crystal.rotation_degrees = Vector3(0, 45, 0)
			_spin.add_child(crystal)
			var halo := MeshInstance3D.new()
			var halo_mesh := TorusMesh.new()
			halo_mesh.inner_radius = 0.5
			halo_mesh.outer_radius = 0.58
			halo_mesh.rings = 24
			halo_mesh.ring_segments = 6
			halo.mesh = halo_mesh
			var halo_material := StandardMaterial3D.new()
			halo_material.albedo_color = color
			halo_material.emission_enabled = true
			halo_material.emission = color
			halo_material.emission_energy_multiplier = 1.2
			halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			halo.material_override = halo_material
			halo.rotation_degrees = Vector3(18, 0, 0)
			_spin.add_child(halo)

	_build_pips(color)
	_build_range_ring(color)
	_start_idle_animation()


func _build_pips(color: Color) -> void:
	for i in TowerData.MAX_LEVEL:
		var pip := MeshInstance3D.new()
		var pip_mesh := SphereMesh.new()
		pip_mesh.radius = 0.08
		pip_mesh.height = 0.16
		pip.mesh = pip_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pip.material_override = material
		pip.position = Vector3(-0.28 + 0.28 * i, 0.62, -0.82)
		add_child(pip)
		_pips.append(pip)


func _build_range_ring(color: Color) -> void:
	_range_ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.97
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 4
	_range_ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.7
	_range_ring.material_override = material
	_range_ring.position.y = 0.16
	_range_ring.visible = false
	add_child(_range_ring)


func _start_idle_animation() -> void:
	if _spin == null:
		return
	var tween := _spin.create_tween()
	tween.set_loops()
	tween.tween_property(_spin, "rotation:y", TAU, 4.0).from(0.0)
