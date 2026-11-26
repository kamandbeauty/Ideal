extends "res://scripts/environment/hospital_geometry.gd"
## Stadium pitch on the existing combat lanes. All seating, field markings,
## goal and scoreboard are decorative; ground and permanent defenses collide.


func _ready() -> void:
	_setup_materials()
	(materials["concrete"] as StandardMaterial3D).albedo_color = Color(0.50, 0.50, 0.46)
	(materials["trim"] as StandardMaterial3D).albedo_color = Color(0.24, 0.28, 0.30)
	(materials["red"] as StandardMaterial3D).albedo_color = Color(0.62, 0.28, 0.20)
	materials["stadium_grass"] = _material(Color(0.72, 0.76, 0.66))
	_textured("stadium_grass", "stadium_grass", Vector3(16, 20, 1))
	materials["stadium_mark"] = _material(Color(0.78, 0.77, 0.67))
	materials["stadium_steel"] = _material(Color(0.19, 0.25, 0.27), 0.2)
	materials["stadium_seat_blue"] = _material(Color(0.12, 0.31, 0.38))
	materials["stadium_seat_red"] = _material(Color(0.48, 0.20, 0.15))
	materials["stadium_score"] = _material(Color(0.08, 0.12, 0.13))
	materials["stadium_light"] = _material(Color(0.86, 0.78, 0.50))
	var light: StandardMaterial3D = materials["stadium_light"]
	light.emission_enabled = true
	light.emission = Color(0.9, 0.75, 0.4)
	light.emission_energy_multiplier = 0.65
	_box("StadiumGround", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "stadium_grass", true)
	_box("StadiumPlatform", Vector3(0, 1.9, 5), Vector3(31, 3.8, 16), "concrete", true)
	_box("StadiumPlatformTop", Vector3(0, 3.95, 5), Vector3(32, 0.1, 16), "concrete")
	_defenses()
	_stadium()


func _defenses() -> void:
	_wall_segment("WestWallFar", -16.8, -39.0, 18.0)
	_wall_segment("WestWallNear", -16.8, -12.0, 22.0)
	_wall_segment("EastWallFar", 16.65, -35.25, 25.5)
	_wall_segment("EastWallNear", 16.65, -7.0, 17.0)
	_box("WallPatch", Vector3(-16.8, 1.9, -26.5), Vector3(0.6, 3.8, 7), "trim")
	_box("GateLeafA", Vector3(16.65, 2.1, -20.75), Vector3(0.4, 4.2, 3.5), "trim")
	_box("GateLeafB", Vector3(16.65, 2.1, -17.25), Vector3(0.4, 4.2, 3.5), "trim")
	for side: int in [-1, 1]:
		var z: float = -26.5 if side < 0 else -19.0
		_box("StadiumGateHeader%d" % side, Vector3(side * 16.7, 4.5, z), Vector3(0.8, 0.6, 8), "red")
		for offset: float in [-3.7, 3.7]:
			_box("StadiumGatePost%d_%s" % [side, offset], Vector3(side * 16.7, 2.0, z + offset), Vector3(0.8, 4, 0.35), "concrete")


func _stadium() -> void:
	var stands: Array[Transform3D] = []
	var steel: Array[Transform3D] = []
	var seats_blue: Array[Transform3D] = []
	var seats_red: Array[Transform3D] = []
	var lines: Array[Transform3D] = []
	var goal: Array[Transform3D] = []
	var board: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	# Back terraces lie behind the last spawn points, and the flanking stands
	# remain outside the arena lanes. Seating is drawn in two material batches.
	for row: int in 6:
		var y: float = 2.2 + row * 1.8
		var z: float = -152.0 - row * 2.7
		_detail(stands, Vector3(0, y - 0.6, z), Vector3(76, 1.2, 2.7))
		for col: int in 32:
			var x: float = -35.65 + col * 2.3
			var seat: Array[Transform3D] = seats_blue if (row + col / 4) % 2 == 0 else seats_red
			_detail(seat, Vector3(x, y + 0.25, z + 0.35), Vector3(1.15, 0.65, 0.6))
	for side: int in [-1, 1]:
		for row: int in 5:
			var x: float = side * (40.0 + row * 2.5)
			var y: float = 2.0 + row * 1.7
			_detail(stands, Vector3(x, y - 0.6, -108), Vector3(2.5, 1.2, 54))
			for col: int in 21:
				var seat: Array[Transform3D] = seats_blue if (row + col / 4) % 2 == 0 else seats_red
				_detail(seat, Vector3(x - side * 0.25, y + 0.25, -132.0 + col * 2.4), Vector3(0.6, 0.65, 1.15))
		_detail(steel, Vector3(side * 37.0, 12.5, -108), Vector3(0.3, 0.35, 54))
		for z: float in [-132.0, -120.0, -108.0, -96.0, -84.0]:
			_detail(steel, Vector3(side * 37.0, 6.2, z), Vector3(0.35, 12.4, 0.35))
	# Full-size goal behind the spawn line, with a suggestive wire net. It has
	# no collision and does not block routes or projectiles.
	for x: float in [-9.0, 9.0]:
		_detail(goal, Vector3(x, 2.8, -145), Vector3(0.22, 5.6, 0.22))
	_detail(goal, Vector3(0, 5.6, -145), Vector3(18.2, 0.22, 0.22))
	for x: int in range(-8, 9, 2):
		_detail(steel, Vector3(x, 2.8, -146.1), Vector3(0.055, 5.5, 0.055))
	for y: float in [0.6, 1.6, 2.6, 3.6, 4.6, 5.5]:
		_detail(steel, Vector3(0, y, -146.1), Vector3(18, 0.05, 0.05))
	# Raised scoreboard with simple fixed numerals, not a live game UI.
	_detail(board, Vector3(0, 24, -150), Vector3(23, 8, 0.8))
	_detail(steel, Vector3(-11.8, 18, -150), Vector3(0.6, 12, 0.8))
	_detail(steel, Vector3(11.8, 18, -150), Vector3(0.6, 12, 0.8))
	for x: float in [-6.0, 6.0]:
		_detail(lights, Vector3(x, 24, -149.55), Vector3(3.0, 3.5, 0.08))
	_detail(lights, Vector3(0, 24, -149.5), Vector3(0.4, 2.0, 0.08))
	for side: int in [-1, 1]:
		_detail(steel, Vector3(side * 31, 24, -146), Vector3(0.7, 24, 0.7))
		_detail(steel, Vector3(side * 31, 36, -146), Vector3(9, 3.2, 0.6))
		for col: int in 4:
			_detail(lights, Vector3(side * 31 - 3.0 + col * 2.0, 36, -145.65), Vector3(1.3, 1.7, 0.08))
	# Pitch lines remain flush and leave the central sightline unobstructed.
	for x: float in [-20.0, 20.0]:
		_detail(lines, Vector3(x, 0.018, -95), Vector3(0.16, 0.018, 96))
	for z: float in [-142.0, -94.0, -48.0]:
		_detail(lines, Vector3(0, 0.018, z), Vector3(40, 0.018, 0.16))
	for x: float in [-12.0, 12.0]:
		_detail(lines, Vector3(x, 0.018, -135), Vector3(0.16, 0.018, 14))
	_detail(lines, Vector3(0, 0.018, -128), Vector3(24, 0.018, 0.16))
	_batch("StadiumTerraces", stands, BoxMesh.new(), materials["concrete"])
	_batch("StadiumStructures", steel, BoxMesh.new(), materials["stadium_steel"])
	_batch("StadiumBlueSeats", seats_blue, BoxMesh.new(), materials["stadium_seat_blue"])
	_batch("StadiumRedSeats", seats_red, BoxMesh.new(), materials["stadium_seat_red"])
	_batch("StadiumPitchLines", lines, BoxMesh.new(), materials["stadium_mark"])
	_batch("StadiumGoal", goal, BoxMesh.new(), materials["stadium_mark"])
	_batch("StadiumScoreboard", board, BoxMesh.new(), materials["stadium_score"])
	_batch("StadiumFloodlights", lights, BoxMesh.new(), materials["stadium_light"])
	var center_circle := MeshInstance3D.new()
	center_circle.name = "StadiumCenterCircle"
	var ring := TorusMesh.new()
	ring.inner_radius = 8.9
	ring.outer_radius = 9.05
	ring.rings = 32
	ring.ring_segments = 8
	center_circle.mesh = ring
	center_circle.material_override = materials["stadium_mark"]
	center_circle.position = Vector3(0, 0.025, -94)
	center_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(center_circle)


func _detail(items: Array[Transform3D], at: Vector3, size: Vector3) -> void:
	items.append(Transform3D(Basis.from_scale(size), at))


func _batch(batch_name: String, items: Array[Transform3D], mesh: PrimitiveMesh, material: Material) -> void:
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = items.size()
	for index: int in items.size():
		multi.set_instance_transform(index, items[index])
	var node := MultiMeshInstance3D.new()
	node.name = batch_name
	node.multimesh = multi
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
