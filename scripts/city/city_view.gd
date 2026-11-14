class_name CityView
extends Node3D
## Draws the island and keeps two GridMaps in sync with the city: one for the
## auto-tiled road network, one for buildings, parks and paving.

const MAP_Y := 0.02
const CURSOR_Y := 0.06

var state: CityState

var _road_map: GridMap
var _building_map: GridMap
var _items: Dictionary = {}
var _orientations: Dictionary = {}
var _cursor: Node3D
var _cursor_material: StandardMaterial3D
var _preview: Node3D
var _selected_id := ""
var _preview_rotation := 0
var _cursor_cell := CityData.INVALID_CELL


func setup(city_state: CityState) -> void:
	state = city_state
	_build_environment()
	_build_land()
	_build_grid_lines()
	_build_maps()
	_build_cursor()
	rebuild()


func rebuild() -> void:
	_road_map.clear()
	_building_map.clear()
	for cell in state.cells:
		_update_cell(cell)


## Refreshes a cell and its neighbours (road pieces depend on their edges).
func refresh_area(cell: Vector2i) -> void:
	_update_cell(cell)
	for neighbor in CityData.neighbors(cell):
		_update_cell(neighbor)


func set_selection(structure_id: String, rotation: int) -> void:
	_selected_id = structure_id
	_preview_rotation = rotation
	_refresh_preview()


func update_cursor(cell: Vector2i, valid: bool) -> void:
	_cursor_cell = cell
	if cell == CityData.INVALID_CELL:
		_cursor.visible = false
		if _preview != null:
			_preview.visible = false
		return
	_cursor.visible = true
	_cursor.position = Vector3(float(cell.x), CURSOR_Y, float(cell.y))
	_cursor_material.albedo_color = UiTheme.GOOD if valid else UiTheme.DANGER
	_cursor_material.emission = UiTheme.GOOD if valid else UiTheme.DANGER
	_refresh_preview()


func hide_cursor() -> void:
	update_cursor(CityData.INVALID_CELL, false)


## Grid cell under a screen position, or INVALID_CELL when the ray misses the
## island.
func cell_from_screen(screen_position: Vector2, camera: Camera3D) -> Vector2i:
	if camera == null or state == null:
		return CityData.INVALID_CELL
	var from := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var ground := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground.intersects_ray(from, direction)
	if hit == null:
		return CityData.INVALID_CELL
	var cell := Vector2i(roundi(hit.x), roundi(hit.z))
	if not state.cell_in_bounds(cell):
		return CityData.INVALID_CELL
	return cell


# --- Grid updates -----------------------------------------------------------

func _update_cell(cell: Vector2i) -> void:
	if not state.cell_in_bounds(cell):
		return
	var position := Vector3i(cell.x, 0, cell.y)
	var id := state.structure_at(cell)

	if id.is_empty():
		_road_map.set_cell_item(position, GridMap.INVALID_CELL)
		_building_map.set_cell_item(position, GridMap.INVALID_CELL)
		return

	if id == "road":
		var piece := CityData.road_piece(CityData.road_mask(state.cells, cell))
		var road_item := int(_items.get(str(piece["model"]), GridMap.INVALID_CELL))
		_road_map.set_cell_item(position, road_item, _orientation(int(piece["rotation"])))
		_building_map.set_cell_item(position, GridMap.INVALID_CELL)
	else:
		var item := int(_items.get(CityData.model_of(id), GridMap.INVALID_CELL))
		_road_map.set_cell_item(position, GridMap.INVALID_CELL)
		_building_map.set_cell_item(position, item, _orientation(state.rotation_at(cell)))


func _orientation(rotation_steps: int) -> int:
	var steps := posmod(rotation_steps, 4)
	if _orientations.has(steps):
		return int(_orientations[steps])
	var orientation := _building_map.get_orthogonal_index_from_basis(
		Basis(Vector3.UP, steps * PI / 2.0)
	)
	_orientations[steps] = orientation
	return orientation


func _refresh_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
	if _selected_id.is_empty() or _cursor_cell == CityData.INVALID_CELL:
		return
	var model := "road-straight" if _selected_id == "road" else CityData.model_of(_selected_id)
	var path := CityData.model_path(model)
	if path.is_empty():
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	_preview = packed.instantiate()
	_preview.position = Vector3(float(_cursor_cell.x), CURSOR_Y + 0.01, float(_cursor_cell.y))
	_preview.rotation.y = 0.0 if _selected_id == "road" else _preview_rotation * PI / 2.0
	add_child(_preview)
	_make_ghost(_preview)


func _make_ghost(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.transparency = 0.55
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_make_ghost(child)


# --- World ------------------------------------------------------------------

func _build_maps() -> void:
	var library := MeshLibrary.new()
	var item_id := 0
	for model_id in CityData.MODEL_PATHS:
		var packed := load(CityData.model_path(model_id)) as PackedScene
		if packed == null:
			continue
		var mesh := _extract_mesh(packed)
		if mesh == null:
			continue
		library.create_item(item_id)
		library.set_item_mesh(item_id, mesh)
		_items[model_id] = item_id
		item_id += 1

	_road_map = GridMap.new()
	_road_map.name = "Roads"
	_road_map.mesh_library = library
	_road_map.position.y = MAP_Y
	add_child(_road_map)

	_building_map = GridMap.new()
	_building_map.name = "Buildings"
	_building_map.mesh_library = library
	_building_map.position.y = MAP_Y
	add_child(_building_map)


func _extract_mesh(packed: PackedScene) -> Mesh:
	var instance := packed.instantiate()
	var mesh_instance := _find_mesh_instance(instance)
	var mesh: Mesh = null
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh = mesh_instance.mesh.duplicate()
	instance.free()
	return mesh


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			return mesh_instance
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.3, 0.52, 0.82)
	sky_material.sky_horizon_color = Color(0.72, 0.83, 0.92)
	sky_material.ground_bottom_color = Color(0.16, 0.24, 0.28)
	sky_material.ground_horizon_color = Color(0.6, 0.7, 0.78)
	sky_material.sun_angle_max = 20.0

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.82, 0.9)
	environment.fog_density = 0.0035

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_land() -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(160.0, 0.4, 160.0)
	water.mesh = water_mesh
	water.material_override = _material(Color(0.13, 0.4, 0.6), 0.15)
	water.position.y = -1.15
	add_child(water)

	var shore := MeshInstance3D.new()
	shore.name = "Shore"
	var shore_mesh := BoxMesh.new()
	shore_mesh.size = Vector3(CityData.GRID_SIZE + 3.0, 0.9, CityData.GRID_SIZE + 3.0)
	shore.mesh = shore_mesh
	shore.material_override = _material(Color(0.62, 0.55, 0.4), 1.0)
	shore.position.y = -0.58
	add_child(shore)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(CityData.GRID_SIZE, 1.0, CityData.GRID_SIZE)
	ground.mesh = ground_mesh
	ground.material_override = _material(Color(0.36, 0.62, 0.31), 0.95)
	ground.position.y = -0.5
	add_child(ground)


func _build_grid_lines() -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.14)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in CityData.GRID_SIZE + 1:
		var offset := float(i - CityData.HALF_GRID)
		var half := float(CityData.HALF_GRID)
		mesh.surface_add_vertex(Vector3(offset, 0.0, -half))
		mesh.surface_add_vertex(Vector3(offset, 0.0, half))
		mesh.surface_add_vertex(Vector3(-half, 0.0, offset))
		mesh.surface_add_vertex(Vector3(half, 0.0, offset))
	mesh.surface_end()

	var lines := MeshInstance3D.new()
	lines.name = "GridLines"
	lines.mesh = mesh
	lines.position.y = 0.012
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines)


func _build_cursor() -> void:
	_cursor = Node3D.new()
	_cursor.name = "Cursor"
	add_child(_cursor)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.48
	torus.rings = 28
	torus.ring_segments = 6
	ring.mesh = torus
	_cursor_material = StandardMaterial3D.new()
	_cursor_material.albedo_color = UiTheme.GOOD
	_cursor_material.emission_enabled = true
	_cursor_material.emission = UiTheme.GOOD
	_cursor_material.emission_energy_multiplier = 1.4
	_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = _cursor_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.add_child(ring)
	_cursor.visible = false


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
