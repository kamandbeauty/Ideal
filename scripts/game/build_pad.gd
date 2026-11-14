class_name BuildPad
extends StaticBody3D
## A platform on which the player can raise one tower.

var pad_index := 0
var tower: Tower

var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _selected := false


func setup(index: int) -> void:
	pad_index = index
	collision_layer = 2
	collision_mask = 0
	add_to_group("build_pads")

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = LevelData.PAD_RADIUS
	cylinder.height = 1.2
	shape.shape = cylinder
	shape.position.y = 0.6
	add_child(shape)

	var platform := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = LevelData.PAD_RADIUS
	mesh.bottom_radius = LevelData.PAD_RADIUS + 0.12
	mesh.height = 0.28
	platform.mesh = mesh
	platform.position.y = 0.14
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.21, 0.26, 0.33)
	stone.roughness = 0.95
	platform.material_override = stone
	add_child(platform)

	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = UiTheme.ACCENT
	_ring_material.emission_enabled = true
	_ring_material.emission = UiTheme.ACCENT
	_ring_material.emission_energy_multiplier = 0.6
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = LevelData.PAD_RADIUS - 0.14
	torus.outer_radius = LevelData.PAD_RADIUS
	torus.rings = 28
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.material_override = _ring_material
	_ring.position.y = 0.32
	add_child(_ring)


func set_tower(next_tower: Tower) -> void:
	tower = next_tower
	if _ring != null:
		_ring.visible = tower == null


func set_selected(selected: bool) -> void:
	_selected = selected
	if _ring_material == null:
		return
	_ring_material.albedo_color = UiTheme.GOLD if selected else UiTheme.ACCENT
	_ring_material.emission = UiTheme.GOLD if selected else UiTheme.ACCENT
	_ring_material.emission_energy_multiplier = 2.2 if selected else 0.6


func is_selected() -> bool:
	return _selected
