class_name GuildHall
extends Node3D
## The guild hall: one room with nine named zones, furniture you can bump into,
## and a navigation mesh the customers can walk on.
##
## The layout comes from `GuildHallZones`, so the geometry, the colliders, the
## navigation grid and the tests all read one table. The navigation mesh is
## authored here (a 1.5 m grid with the furniture cut out) instead of being baked,
## because nobody can bake a navmesh in CI.

const NAV_CELL := 1.0
const NAV_MARGIN := 0.55
const FLOOR_COLOR := Color(0.14, 0.15, 0.22)
const WALL_COLOR := Color(0.2, 0.21, 0.31)
const WOOD := Color(0.34, 0.24, 0.18)
const IRON := Color(0.42, 0.45, 0.56)
const GOLD := Color(0.92, 0.76, 0.38)
const RUG := Color(0.17, 0.13, 0.28)
const CUSHION := Color(0.55, 0.25, 0.35)
const TRIM := Color(0.62, 0.5, 0.27)
const LANTERN := Color(1.0, 0.84, 0.52)
const RUNE := Color(0.36, 0.88, 0.9)

var nav_region: NavigationRegion3D
var zone_nodes: Dictionary = {}
var zone_labels: Dictionary = {}
var language := "en"

var _props_root: Node3D
var _solid: StaticBody3D


func _ready() -> void:
	build()


## Builds the room. Public so a test or a tool can build it on demand.
func build() -> void:
	if _props_root != null:
		return
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	add_child(_solid)
	_props_root = Node3D.new()
	_props_root.name = "Props"
	add_child(_props_root)
	_build_floor()
	_build_walls()
	_build_zones()
	_build_props()
	_build_decor()
	_build_lighting()
	_build_navmesh()


## Relabels the nine zone signs. Only the words change, never the geometry.
func set_language(new_language: String) -> void:
	language = "fa" if new_language == "fa" else "en"
	for id in zone_labels:
		var label := zone_labels[id] as Label3D
		if label == null:
			continue
		var data := GuildHallZones.zone(str(id))
		label.text = GuildLocale.t(str(data.get("name_key", "")), [], language)


func navmesh_report() -> String:
	if nav_region == null or nav_region.navigation_mesh == null:
		return "navmesh: none"
	var mesh := nav_region.navigation_mesh
	return "navmesh polygons=%d vertices=%d regions=%d" % [
		mesh.get_polygon_count(),
		mesh.get_vertices().size(),
		NavigationServer3D.map_get_regions(get_world_3d().navigation_map).size(),
	]


## Asks the navigation server for a route, which is the only honest way to know
## that the authored mesh works. Returns a line for the play-through report.
func check_path(from: Vector3, to: Vector3) -> String:
	if not is_inside_tree():
		return "path: not in tree"
	var map := get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var length := 0.0
	for index in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return "path %s -> %s points=%d length=%.1f" % [
		_area_label(from),
		_area_label(to),
		path.size(),
		length,
	]


func _area_label(point: Vector3) -> String:
	var zone_id := GuildHallZones.zone_at(point)
	return zone_id if not zone_id.is_empty() else "outside"


# --- floor, walls ----------------------------------------------------------

func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(GuildHallZones.WIDTH, GuildHallZones.DEPTH)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.material_override = GuildMaterials.floor(FLOOR_COLOR)
	add_child(floor_mesh)

	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorBody"
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GuildHallZones.WIDTH, 1.0, GuildHallZones.DEPTH)
	collider.shape = box
	collider.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(collider)
	add_child(floor_body)

	var inlay := Node3D.new()
	inlay.name = "ZoneFloors"
	add_child(inlay)
	for id in GuildHallZones.zone_ids():
		var data := GuildHallZones.zone(id)
		var rect := data["rect"] as Rect2
		var patch := MeshInstance3D.new()
		patch.name = "Floor_" + id
		var patch_mesh := BoxMesh.new()
		patch_mesh.size = Vector3(rect.size.x - 0.5, 0.03, rect.size.y - 0.5)
		patch.mesh = patch_mesh
		patch.material_override = GuildMaterials.flat(data["floor"] as Color)
		patch.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.016, rect.position.y + rect.size.y * 0.5)
		inlay.add_child(patch)


func _build_walls() -> void:
	var half_w := GuildHallZones.WIDTH * 0.5
	var half_d := GuildHallZones.DEPTH * 0.5
	var thickness := GuildHallZones.WALL_THICKNESS
	var height := GuildHallZones.WALL_HEIGHT

	# North and south walls, then the west and east ones.
	_wall(Vector3(0.0, 0.0, -half_d), Vector3(GuildHallZones.WIDTH, height, thickness))
	_wall(Vector3(0.0, 0.0, half_d), Vector3(GuildHallZones.WIDTH, height, thickness))
	_wall(Vector3(-half_w, 0.0, 0.0), Vector3(thickness, height, GuildHallZones.DEPTH))
	_wall(Vector3(half_w, 0.0, 0.0), Vector3(thickness, height, GuildHallZones.DEPTH))

	# The door: a gap in the south wall with a frame around it.
	var door_half := GuildHallZones.DOOR_WIDTH * 0.5
	var door_x := GuildHallZones.spawn("door").x
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.28, 3.4, 0.62)
		post.mesh = post_mesh
		post.material_override = GuildMaterials.metal(GOLD.darkened(0.2))
		post.position = Vector3(door_x + (door_half + 0.14) * side, 1.7, half_d)
		add_child(post)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(GuildHallZones.DOOR_WIDTH + 0.56, 0.32, 0.62)
	lintel.mesh = lintel_mesh
	lintel.material_override = GuildMaterials.metal(GOLD.darkened(0.2))
	lintel.position = Vector3(door_x, 3.5, half_d)
	add_child(lintel)

	# Two banners over the door so the entrance reads from across the room.
	for side in [-1.0, 1.0]:
		var banner := MeshInstance3D.new()
		var banner_mesh := BoxMesh.new()
		banner_mesh.size = Vector3(1.1, 2.6, 0.08)
		banner.mesh = banner_mesh
		banner.material_override = GuildMaterials.flat(Color(0.22, 0.24, 0.56))
		banner.position = Vector3(door_x + (door_half + 1.6) * side, 4.2, half_d - 0.36)
		add_child(banner)


func _wall(center: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = GuildMaterials.flat(WALL_COLOR)
	mesh.position = center + Vector3(0.0, size.y * 0.5, 0.0)
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	shape.position = mesh.position
	_solid.add_child(shape)


# --- zones -----------------------------------------------------------------

func _build_zones() -> void:
	for id in GuildHallZones.zone_ids():
		var node := Node3D.new()
		node.name = "Zone_" + id
		node.position = GuildHallZones.center(id)
		node.set_meta("zone", id)
		add_child(node)
		zone_nodes[id] = node

		var data := GuildHallZones.zone(id)
		var label := Label3D.new()
		label.name = "Label"
		label.text = GuildLocale.t(str(data["name_key"]), [], "en")
		label.font_size = 48
		label.pixel_size = 0.009
		label.modulate = Color(0.86, 0.88, 1.0, 0.9)
		label.outline_size = 12
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.position = Vector3(0.0, 2.6, 0.0)
		node.add_child(label)
		zone_labels[id] = label

	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var rug_mesh := BoxMesh.new()
	rug_mesh.size = Vector3(6.0, 0.03, 4.0)
	rug.mesh = rug_mesh
	rug.material_override = GuildMaterials.flat(RUG)
	rug.position = Vector3(0.0, 0.04, 6.4)
	add_child(rug)


# --- props -----------------------------------------------------------------

func _build_props() -> void:
	for prop in GuildHallZones.PROPS:
		_build_prop(prop as Dictionary)


func _build_prop(prop: Dictionary) -> void:
	var rect := prop["rect"] as Rect2
	var height := float(prop["height"])
	var kind := str(prop["kind"])
	var center := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)

	var root := Node3D.new()
	root.name = "Prop_" + kind
	root.position = center
	root.set_meta("kind", kind)
	_props_root.add_child(root)

	match kind:
		"counter":
			_block(root, Vector3(rect.size.x, height, rect.size.y), WOOD, Vector3(0.0, height * 0.5, 0.0))
			var lip := Vector3(rect.size.x + 0.16, 0.12, rect.size.y + 0.16)
			_block(root, lip, WOOD.lightened(0.18), Vector3(0.0, height, 0.0))
		"shelf":
			_block(root, Vector3(rect.size.x, height, rect.size.y), WOOD.darkened(0.2), Vector3(0.0, height * 0.5, 0.0))
			for index in 3:
				var shelf_board := Vector3(rect.size.x + 0.1, 0.07, rect.size.y)
				_block(root, shelf_board, GOLD.darkened(0.25), Vector3(0.0, 0.5 + index * 0.55, 0.0))
		"rack":
			var upright := Vector3(rect.size.x, height, 0.12)
			_block(root, upright, IRON, Vector3(0.0, height * 0.5, -rect.size.y * 0.5 + 0.06))
			_block(root, upright, IRON, Vector3(0.0, height * 0.5, rect.size.y * 0.5 - 0.06))
			for index in 3:
				var shelf_y := 0.5 + index * 0.75
				_block(root, Vector3(rect.size.x, 0.08, rect.size.y), WOOD, Vector3(0.0, shelf_y, 0.0))
				for parcel in 2:
					_block(
							root,
							Vector3(0.22, 0.16, 0.2),
							Color(0.6, 0.34, 0.72).darkened(0.08 * parcel),
							Vector3(-0.12 + parcel * 0.3, shelf_y + 0.12, -0.5 + index * 0.5)
					)
		"crate":
			_block(root, Vector3(rect.size.x, height, rect.size.y), WOOD.darkened(0.08), Vector3(0.0, height * 0.5, 0.0))
			var rim := Vector3(rect.size.x + 0.06, 0.08, rect.size.y + 0.06)
			_block(root, rim, GOLD.darkened(0.35), Vector3(0.0, height - 0.04, 0.0))
		"bench":
			_block(root, Vector3(rect.size.x, 0.2, rect.size.y), WOOD, Vector3(0.0, 0.45, 0.0))
			_block(root, Vector3(rect.size.x, 0.28, rect.size.y * 0.8), CUSHION, Vector3(0.0, 0.68, 0.0))
			_block(root, Vector3(0.16, 0.4, rect.size.y * 0.8), WOOD.darkened(0.25), Vector3(-rect.size.x * 0.4, 0.22, 0.0))
			_block(root, Vector3(0.16, 0.4, rect.size.y * 0.8), WOOD.darkened(0.25), Vector3(rect.size.x * 0.4, 0.22, 0.0))
		"plant":
			_block(root, Vector3(rect.size.x * 0.8, 0.5, rect.size.y * 0.8), Color(0.3, 0.22, 0.2), Vector3(0.0, 0.25, 0.0))
			var leaves := SphereMesh.new()
			leaves.radius = rect.size.x * 0.55
			leaves.height = height * 0.6
			_block_mesh(root, leaves, Color(0.28, 0.52, 0.36), Vector3(0.0, height * 0.7, 0.0))
		"board":
			_block(root, Vector3(rect.size.x, height, rect.size.y), WOOD.darkened(0.15), Vector3(0.0, height * 0.5, 0.0))
			var panel := Vector3(rect.size.x - 0.3, height - 0.5, 0.06)
			var panel_at := Vector3(0.0, height * 0.5, rect.size.y * 0.5 + 0.04)
			_block(root, panel, Color(0.1, 0.11, 0.18), panel_at)
			for index in 4:
				var paper := Vector3(0.42, 0.5, 0.03)
				var paper_at := Vector3(
						-rect.size.x * 0.32 + index * 0.55,
						height * 0.52 + (index % 2) * 0.2,
						rect.size.y * 0.5 + 0.09
				)
				_block(root, paper, Color(0.92, 0.88, 0.76), paper_at)
		"chest":
			_block(root, Vector3(rect.size.x, height * 0.7, rect.size.y), WOOD.darkened(0.1), Vector3(0.0, height * 0.35, 0.0))
			var lid := Vector3(rect.size.x + 0.08, 0.16, rect.size.y + 0.08)
			_block(root, lid, GOLD.darkened(0.1), Vector3(0.0, height * 0.78, 0.0))
			_block(root, Vector3(0.26, 0.3, 0.1), GOLD, Vector3(0.0, height * 0.5, rect.size.y * 0.5 + 0.03))
			for index in 3:
				var coin := CylinderMesh.new()
				coin.top_radius = 0.11
				coin.bottom_radius = 0.11
				coin.height = 0.04
				_block_mesh(root, coin, GOLD, Vector3(-0.3 + index * 0.3, height * 0.84, 0.0))
		"stair":
			var steps := 5
			for index in steps:
				var step_height := height / steps
				_block(
						root,
						Vector3(rect.size.x, step_height, rect.size.y * (1.0 - index * 0.12)),
						Color(0.3, 0.31, 0.42),
						Vector3(0.0, step_height * (index + 0.5), -rect.size.y * 0.06 * index)
				)
		"dummy":
			_block(root, Vector3(0.24, height, 0.24), WOOD.darkened(0.3), Vector3(0.0, height * 0.5, 0.0))
			_block(root, Vector3(0.5, 0.9, 0.34), Color(0.62, 0.5, 0.32), Vector3(0.0, height * 0.62, 0.0))
			var head := SphereMesh.new()
			head.radius = 0.18
			head.height = 0.36
			_block_mesh(root, head, Color(0.7, 0.6, 0.42), Vector3(0.0, height * 0.94, 0.0))
			_block(root, Vector3(1.0, 0.1, 0.1), WOOD, Vector3(0.0, height * 0.74, 0.0))
		"brazier":
			_block(root, Vector3(0.3, height * 0.6, 0.3), IRON.darkened(0.2), Vector3(0.0, height * 0.3, 0.0))
			var bowl := CylinderMesh.new()
			bowl.top_radius = rect.size.x * 0.6
			bowl.bottom_radius = 0.18
			bowl.height = 0.3
			_block_mesh(root, bowl, IRON, Vector3(0.0, height * 0.62, 0.0))
			var flame := SphereMesh.new()
			flame.radius = 0.13
			flame.height = 0.3
			_block_mesh(root, flame, Color(1.0, 0.62, 0.24), Vector3(0.0, height * 0.82, 0.0), true)
		_:
			_block(root, Vector3(rect.size.x, height, rect.size.y), WOOD, Vector3(0.0, height * 0.5, 0.0))

	# One collider per prop, sized to its footprint: the player bumps into the
	# furniture instead of walking through it.
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = Vector3(rect.size.x, height, rect.size.y)
	shape.shape = collider
	shape.position = center + Vector3(0.0, height * 0.5, 0.0)
	_solid.add_child(shape)


func _block(parent: Node3D, size: Vector3, color: Color, position: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _block_mesh(parent, mesh, color, position, false)


func _block_mesh(
		parent: Node3D, mesh: Mesh, color: Color, position: Vector3, glowing: bool = false
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = GuildMaterials.glow(color, 1.0) if glowing else GuildMaterials.flat(color)
	instance.position = position
	parent.add_child(instance)
	return instance


# --- light and navigation --------------------------------------------------

func _build_lighting() -> void:
	var key := DirectionalLight3D.new()
	key.name = "Moonlight"
	key.rotation_degrees = Vector3(-58.0, 42.0, 0.0)
	key.light_color = Color(0.78, 0.85, 1.0)
	key.light_energy = 0.95
	key.shadow_enabled = true
	key.shadow_bias = 0.04
	key.directional_shadow_max_distance = 46.0
	add_child(key)

	# A cool violet fill from the opposite side, without shadows: it lifts the
	# shadowed half of every wall so the deep-blue palette never turns to mud.
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-34.0, -138.0, 0.0)
	fill.light_color = Color(0.56, 0.5, 0.96)
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	add_child(fill)

	var lamps := [
		{"zone": "counter", "color": Color(1.0, 0.8, 0.52)},
		{"zone": "warehouse", "color": Color(0.82, 0.9, 1.0)},
		{"zone": "hall", "color": Color(0.72, 0.8, 1.0)},
		{"zone": "treasury", "color": Color(1.0, 0.78, 0.42)},
	]
	for lamp in lamps:
		var light := OmniLight3D.new()
		var spot := GuildHallZones.center(str(lamp["zone"]))
		light.position = spot + Vector3(0.0, 4.4, 0.0)
		light.light_color = lamp["color"] as Color
		light.light_energy = 9.5
		light.omni_range = 15.0
		light.light_specular = 0.0
		add_child(light)


# --- decoration ------------------------------------------------------------
#
# Everything below is geometry and emission only: it costs no extra lights, so the
# hall keeps its five-light budget on the Low preset and still reads as a place.

func _build_decor() -> void:
	_build_trim()
	_build_zone_trim()
	_build_rug_pattern()
	_build_sconces()
	_build_rune_circle()


## Gold band and dark baseboard around the room: two long strips per wall, which is
## what turns a flat box into a hall.
func _build_trim() -> void:
	var half_w := GuildHallZones.WIDTH * 0.5 - GuildHallZones.WALL_THICKNESS * 0.5
	var half_d := GuildHallZones.DEPTH * 0.5 - GuildHallZones.WALL_THICKNESS * 0.5
	var bands := [
		{"size": Vector3(GuildHallZones.WIDTH - 0.2, 0.12, 0.08), "at": Vector3(0.0, 2.5, -half_d + 0.06)},
		{"size": Vector3(GuildHallZones.WIDTH - 0.2, 0.12, 0.08), "at": Vector3(0.0, 2.5, half_d - 0.06)},
		{"size": Vector3(0.08, 0.12, GuildHallZones.DEPTH - 0.2), "at": Vector3(-half_w + 0.06, 2.5, 0.0)},
		{"size": Vector3(0.08, 0.12, GuildHallZones.DEPTH - 0.2), "at": Vector3(half_w - 0.06, 2.5, 0.0)},
	]
	var boards := [
		{"size": Vector3(GuildHallZones.WIDTH - 0.2, 0.22, 0.1), "at": Vector3(0.0, 0.11, -half_d + 0.07)},
		{"size": Vector3(GuildHallZones.WIDTH - 0.2, 0.22, 0.1), "at": Vector3(0.0, 0.11, half_d - 0.07)},
		{"size": Vector3(0.1, 0.22, GuildHallZones.DEPTH - 0.2), "at": Vector3(-half_w + 0.07, 0.11, 0.0)},
		{"size": Vector3(0.1, 0.22, GuildHallZones.DEPTH - 0.2), "at": Vector3(half_w - 0.07, 0.11, 0.0)},
	]
	for band in bands:
		_plate(band["size"] as Vector3, TRIM, band["at"] as Vector3, true)
	for board in boards:
		_plate(board["size"] as Vector3, WOOD.darkened(0.35), board["at"] as Vector3)


## A gold line around every zone: from the top-down camera the floor plan becomes
## legible at a glance instead of nine similar rectangles.
func _build_zone_trim() -> void:
	for id in GuildHallZones.zone_ids():
		var rect := GuildHallZones.rect(id)
		var color := TRIM.darkened(0.45)
		var y := 0.04
		var thin := 0.05
		_plate(Vector3(rect.size.x, 0.02, thin), color, Vector3(rect.position.x + rect.size.x * 0.5, y, rect.position.y))
		_plate(
			Vector3(rect.size.x, 0.02, thin), color,
			Vector3(rect.position.x + rect.size.x * 0.5, y, rect.position.y + rect.size.y)
		)
		_plate(Vector3(thin, 0.02, rect.size.y), color, Vector3(rect.position.x, y, rect.position.y + rect.size.y * 0.5))
		_plate(
			Vector3(thin, 0.02, rect.size.y), color,
			Vector3(rect.position.x + rect.size.x, y, rect.position.y + rect.size.y * 0.5)
		)


## The rug gets a border and a diamond so it is a carpet and not a purple mat.
func _build_rug_pattern() -> void:
	var center := Vector3(0.0, 0.055, 6.4)
	_plate(Vector3(5.4, 0.02, 3.4), RUG.lightened(0.16), center)
	_plate(Vector3(4.9, 0.025, 2.9), TRIM.darkened(0.1), center)
	_plate(Vector3(4.5, 0.03, 2.5), RUG.lightened(0.06), center)
	var diamond := BoxMesh.new()
	diamond.size = Vector3(1.7, 0.02, 1.7)
	var gem := MeshInstance3D.new()
	gem.mesh = diamond
	gem.material_override = GuildMaterials.glow(RUNE.darkened(0.55), 0.35)
	gem.position = center + Vector3(0.0, 0.01, 0.0)
	gem.rotation.y = deg_to_rad(45.0)
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gem)


## Sconces on the walls. An earlier pass hung lanterns from ceiling beams, but a
## beam crosses the isometric view like a fallen tree and hides the hall, so the
## light sources sit flat against the walls where they cost the camera nothing.
func _build_sconces() -> void:
	var half_d := GuildHallZones.DEPTH * 0.5 - GuildHallZones.WALL_THICKNESS * 0.5
	for side in [-1.0, 1.0]:
		for spot in [-8.5, -2.5, 3.5]:
			var at := Vector3(spot, 2.9, half_d * side)
			_plate(Vector3(0.12, 0.5, 0.12), IRON.darkened(0.25), at + Vector3(0.0, -0.25, -0.16 * side))
			var cup := CylinderMesh.new()
			cup.top_radius = 0.2
			cup.bottom_radius = 0.1
			cup.height = 0.22
			var bowl := MeshInstance3D.new()
			bowl.mesh = cup
			bowl.material_override = GuildMaterials.metal(TRIM)
			bowl.position = at + Vector3(0.0, 0.05, -0.22 * side)
			bowl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bowl)
			var flame := SphereMesh.new()
			flame.radius = 0.12
			flame.height = 0.3
			var fire := MeshInstance3D.new()
			fire.mesh = flame
			fire.material_override = GuildMaterials.glow(LANTERN, 1.0)
			fire.position = at + Vector3(0.0, 0.24, -0.22 * side)
			fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(fire)


## A rune circle in the middle of the hall: the guild's own sigil, and the one
## glowing thing on the floor that draws the eye from the door.
func _build_rune_circle() -> void:
	var center := GuildHallZones.center("hall")
	for ring in [
		{"radius": 2.35, "width": 0.12, "color": RUNE.darkened(0.35), "energy": 0.7},
		{"radius": 1.75, "width": 0.06, "color": Color(0.45, 0.4, 0.78), "energy": 0.5},
	]:
		var mesh := TorusMesh.new()
		mesh.inner_radius = float(ring["radius"]) - float(ring["width"])
		mesh.outer_radius = float(ring["radius"])
		mesh.rings = 48
		mesh.ring_segments = 6
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = GuildMaterials.glow(ring["color"] as Color, float(ring["energy"]))
		node.position = center + Vector3(0.0, 0.06, 0.0)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

	for index in 4:
		var angle := TAU * float(index) / 4.0 + PI * 0.25
		var shard := CylinderMesh.new()
		shard.top_radius = 0.0
		shard.bottom_radius = 0.16
		shard.height = 0.7
		var crystal := MeshInstance3D.new()
		crystal.mesh = shard
		crystal.material_override = GuildMaterials.glow(RUNE.darkened(0.2), 0.9)
		crystal.position = center + Vector3(cos(angle) * 2.05, 0.35, sin(angle) * 2.05)
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(crystal)


## A flat box in world space with no ink outline: trim, plates and floor lines are
## geometry, not props, so they stay cheap.
func _plate(size: Vector3, color: Color, at: Vector3, metallic: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = GuildMaterials.metal(color) if metallic else GuildMaterials.flat(color)
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _build_navmesh() -> void:
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.agent_radius = 0.45
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.35

	var blocked: Array[Rect2] = []
	for obstacle in GuildHallZones.obstacle_rects():
		blocked.append(obstacle.grow(NAV_MARGIN))

	var half_w := GuildHallZones.WIDTH * 0.5 - GuildHallZones.WALL_THICKNESS - NAV_MARGIN
	var half_d := GuildHallZones.DEPTH * 0.5 - GuildHallZones.WALL_THICKNESS - NAV_MARGIN
	var vertices := PackedVector3Array()
	var steps_x := int(floor((half_w * 2.0) / NAV_CELL))
	var steps_z := int(floor((half_d * 2.0) / NAV_CELL))
	for ix in steps_x:
		for iz in steps_z:
			var x0 := -half_w + ix * NAV_CELL
			var z0 := -half_d + iz * NAV_CELL
			var x1 := x0 + NAV_CELL
			var z1 := z0 + NAV_CELL
			if _cell_blocked(x0, z0, x1, z1, blocked):
				continue
			var base := vertices.size()
			vertices.append(Vector3(x0, 0.0, z0))
			vertices.append(Vector3(x0, 0.0, z1))
			vertices.append(Vector3(x1, 0.0, z1))
			vertices.append(Vector3(x1, 0.0, z0))
			# Counter-clockwise seen from above, so the polygon normal points up.
			mesh.add_polygon(PackedInt32Array([base, base + 1, base + 2]))
			mesh.add_polygon(PackedInt32Array([base, base + 2, base + 3]))
	mesh.set_vertices(vertices)

	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	nav_region.navigation_mesh = mesh
	add_child(nav_region)


## A cell is only walkable when its centre *and* all four corners are clear, so a
## navigation vertex can never end up inside furniture.
func _cell_blocked(x0: float, z0: float, x1: float, z1: float, blocked: Array[Rect2]) -> bool:
	var probes := [
		Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5),
		Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1),
	]
	for point in probes:
		for rect in blocked:
			if rect.has_point(point):
				return true
	return false
