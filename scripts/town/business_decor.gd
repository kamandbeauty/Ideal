class_name BusinessDecor
extends RefCounted
## Procedural dressing that turns an upgrade into something you can see.
##
## Every business has four extra stages (levels 2–5). A stage is a small group of
## props built from primitives, so a level-up adds pumps, awnings, balconies or
## neon without needing new art. Emissive materials are registered on the stage
## node so the day cycle can switch them on at night.

const STAGE_LEVELS: Array[int] = [2, 3, 4, 5]

const STEEL := Color(0.72, 0.75, 0.79)
const DARK := Color(0.18, 0.2, 0.24)
const CREAM := Color(0.93, 0.9, 0.82)
const WOOD := Color(0.55, 0.38, 0.22)
const GREEN := Color(0.32, 0.55, 0.3)
const WATER := Color(0.2, 0.55, 0.85)
const TYRE := Color(0.12, 0.13, 0.15)


static func build_stage(id: String, stage: int, accent: Color) -> Node3D:
	var root := Node3D.new()
	var night: Array = []
	match id:
		"gas_station":
			_gas_station(root, stage, accent, night)
		"restaurant":
			_restaurant(root, stage, accent, night)
		"store":
			_store(root, stage, accent, night)
		"workshop":
			_workshop(root, stage, accent, night)
		"motel":
			_motel(root, stage, accent, night)
		"car_wash":
			_car_wash(root, stage, accent, night)
	root.set_meta("night_materials", night)
	return root


# --- Businesses ------------------------------------------------------------

static func _gas_station(root: Node3D, stage: int, accent: Color, night: Array) -> void:
	if stage == 2:
		for x in [-0.55, 0.15]:
			_box(root, Vector3(0.2, 0.5, 0.2), Vector3(x, 0.25, 0.95), CREAM)
			_box(root, Vector3(0.26, 0.07, 0.26), Vector3(x, 0.52, 0.95), accent, 1.6, night)
	if stage == 3:
		for x in [-1.0, 1.0]:
			_cyl(root, 0.06, 1.4, Vector3(x, 0.7, 0.85), STEEL)
		_box(root, Vector3(2.4, 0.12, 1.5), Vector3(0, 1.46, 0.85), Color(0.95, 0.95, 0.94))
		_box(root, Vector3(1.9, 0.03, 1.1), Vector3(0, 1.39, 0.85), accent, 1.2, night)
	if stage == 4:
		_box(root, Vector3(0.08, 1.5, 0.08), Vector3(-1.5, 0.75, -0.65), DARK)
		_box(root, Vector3(0.55, 0.7, 0.07), Vector3(-1.5, 1.62, -0.65), accent, 2.0, night)
		for z in [-1.3, -0.2]:
			_box(root, Vector3(0.07, 0.95, 0.07), Vector3(1.55, 0.47, z), DARK)
			_box(root, Vector3(0.16, 0.16, 0.16), Vector3(1.55, 0.99, z), Color(1, 0.95, 0.8), 2.2, night)
	if stage == 5:
		_box(root, Vector3(1.0, 0.85, 1.0), Vector3(1.45, 0.42, -0.6), CREAM)
		_box(root, Vector3(1.1, 0.08, 1.1), Vector3(1.45, 0.88, -0.6), accent)
		_box(root, Vector3(0.85, 0.05, 0.04), Vector3(1.45, 0.7, -0.06), Color(1, 0.98, 0.9), 2.4, night)


static func _restaurant(root: Node3D, stage: int, accent: Color, night: Array) -> void:
	if stage == 2:
		for x in [-1.35, 1.3]:
			_cyl(root, 0.04, 0.6, Vector3(x, 0.3, 0.95), DARK)
			_cyl(root, 0.24, 0.05, Vector3(x, 0.62, 0.95), WOOD)
			for dx in [-0.33, 0.33]:
				_box(root, Vector3(0.18, 0.2, 0.18), Vector3(x + dx, 0.25, 0.95), DARK)
	if stage == 3:
		_box(root, Vector3(1.7, 0.07, 0.75), Vector3(0, 1.06, 1.16), accent).rotation_degrees.x = -12.0
		for x in [-0.8, 0.8]:
			_cyl(root, 0.03, 1.1, Vector3(x, 0.55, 1.45), DARK)
	if stage == 4:
		_box(root, Vector3(0.95, 0.34, 0.09), Vector3(0, 2.36, 0.15), accent, 2.2, night)
		for x in [-1.3, 1.3]:
			_box(root, Vector3(0.34, 0.2, 0.34), Vector3(x, 0.12, 0.25), GREEN)
	if stage == 5:
		_box(root, Vector3(2.0, 0.06, 1.1), Vector3(0, 0.08, 1.3), WOOD)
		for i in 5:
			_cyl(root, 0.05, 0.05, Vector3(-0.8 + 0.4 * float(i), 1.05, 1.3), Color(1, 0.92, 0.7),
				2.4, night)


static func _store(root: Node3D, stage: int, accent: Color, night: Array) -> void:
	if stage == 2:
		for i in 3:
			_box(root, Vector3(0.3, 0.3, 0.3), Vector3(1.45, 0.15 + 0.3 * float(i % 2), -0.85 + 0.02 * float(i)),
				Color(0.72, 0.6, 0.42))
	if stage == 3:
		_box(root, Vector3(1.35, 0.08, 0.65), Vector3(0, 0.98, 1.16), accent)
		for x in [-0.6, 0.6]:
			_cyl(root, 0.04, 0.95, Vector3(x, 0.48, 1.4), DARK)
	if stage == 4:
		_box(root, Vector3(1.3, 0.55, 0.05), Vector3(0, 0.82, 1.22), Color(1, 0.9, 0.66), 1.8, night)
		_box(root, Vector3(1.1, 0.24, 0.07), Vector3(0, 1.35, 1.22), accent, 2.0, night)
	if stage == 5:
		_box(root, Vector3(1.55, 0.7, 0.95), Vector3(0, 1.78, -0.15), CREAM)
		_box(root, Vector3(1.0, 0.05, 0.05), Vector3(0, 2.02, 0.31), accent, 2.4, night)


static func _workshop(root: Node3D, stage: int, accent: Color, night: Array) -> void:
	if stage == 2:
		for i in 4:
			_cyl(root, 0.24, 0.11, Vector3(1.5, 0.1 + 0.12 * float(i), -0.55), TYRE)
	if stage == 3:
		_box(root, Vector3(1.2, 0.08, 1.5), Vector3(0, 0.1, 0.6), STEEL)
		for x in [-0.55, 0.55]:
			_box(root, Vector3(0.07, 0.55, 0.07), Vector3(x, 0.36, -0.1), DARK)
	if stage == 4:
		_cyl(root, 0.18, 0.5, Vector3(-1.4, 0.25, 0.7), Color(0.72, 0.25, 0.2))
		_box(root, Vector3(0.5, 0.35, 0.35), Vector3(-1.35, 0.18, 0.0), Color(0.7, 0.32, 0.25))
		_box(root, Vector3(0.6, 0.24, 0.06), Vector3(0, 1.55, 0.05), accent, 2.0, night)
	if stage == 5:
		_box(root, Vector3(1.2, 0.95, 1.35), Vector3(1.45, 0.48, 0.55), Color(0.82, 0.82, 0.8))
		_box(root, Vector3(1.35, 0.1, 1.5), Vector3(1.45, 1.0, 0.55), accent)
		_cyl(root, 0.06, 0.5, Vector3(1.95, 1.3, -0.1), DARK)


static func _motel(root: Node3D, stage: int, accent: Color, night: Array) -> void:
	if stage == 2:
		for i in 4:
			_box(root, Vector3(0.05, 0.01, 1.0), Vector3(1.25 + 0.32 * float(i), 0.06, -1.35),
				Color(0.95, 0.95, 0.9))
	if stage == 3:
		_box(root, Vector3(2.2, 0.07, 0.07), Vector3(0, 1.2, 1.25), STEEL)
		for i in 4:
			_box(root, Vector3(0.05, 0.5, 0.05), Vector3(-0.8 + 0.53 * float(i), 0.95, 1.25), STEEL)
		for x in [-1.2, 1.2]:
			_box(root, Vector3(0.4, 0.28, 0.24), Vector3(x, 1.6, 0.2), Color(0.85, 0.85, 0.83))
	if stage == 4:
		_box(root, Vector3(1.3, 0.14, 0.85), Vector3(1.35, 0.1, -1.1), WATER, 1.6, night)
		for z in [-1.35, -0.85]:
			_box(root, Vector3(0.4, 0.08, 0.7), Vector3(-1.35, 0.14, z), Color(0.95, 0.82, 0.62))
	if stage == 5:
		_box(root, Vector3(0.1, 2.4, 0.1), Vector3(-1.6, 1.2, -0.1), DARK)
		_box(root, Vector3(0.7, 0.5, 0.09), Vector3(-1.6, 2.5, -0.1), accent, 2.4, night)
		for i in 4:
			_cyl(root, 0.06, 0.06, Vector3(-1.2 + 0.6 * float(i), 1.35, 1.25), Color(1, 0.92, 0.7),
				2.4, night)


static func _car_wash(root: Node3D, stage: int, accent: Color, night: Array) -> void:
	if stage == 2:
		for x in [1.35, 1.7]:
			_cyl(root, 0.2, 0.5, Vector3(x, 0.25, 0.75), Color(0.25, 0.42, 0.65))
		_cyl(root, 0.16, 0.1, Vector3(1.5, 0.6, 0.4), DARK)
	if stage == 3:
		for x in [-0.85, 0.85]:
			_box(root, Vector3(0.1, 1.7, 0.1), Vector3(x, 0.85, 0.9), STEEL)
		_box(root, Vector3(1.9, 0.14, 0.28), Vector3(0, 1.75, 0.9), accent)
	if stage == 4:
		for x in [-0.62, 0.62]:
			_cyl(root, 0.24, 1.5, Vector3(x, 0.8, 0.9), Color(0.62, 0.82, 0.95))
		_box(root, Vector3(1.6, 0.05, 0.05), Vector3(0, 1.55, 0.9), accent, 2.4, night)
	if stage == 5:
		_box(root, Vector3(0.1, 1.5, 0.1), Vector3(1.5, 0.75, 0.2), STEEL)
		_box(root, Vector3(0.1, 1.5, 0.1), Vector3(-1.5, 0.75, 0.2), STEEL)
		_box(root, Vector3(3.1, 0.12, 0.24), Vector3(0, 1.55, 0.2), accent)
		for i in 2:
			_cyl(root, 0.28, 0.12, Vector3(1.2 - 0.5 * float(i), 1.2, 0.2), Color(0.35, 0.35, 0.38))


# --- Helpers ---------------------------------------------------------------

static func _box(
	parent: Node3D, size: Vector3, pos: Vector3, color: Color,
	emission: float = 0.0, night: Array = []
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color, emission, night)
	node.position = pos
	parent.add_child(node)
	return node


static func _cyl(
	parent: Node3D, radius: float, height: float, pos: Vector3, color: Color,
	emission: float = 0.0, night: Array = []
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = _material(color, emission, night)
	node.position = pos
	parent.add_child(node)
	return node


static func _material(color: Color, emission: float, night: Array) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	material.metallic = 0.1
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission * 0.4
		night.append(material)
	return material
