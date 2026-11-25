extends "res://scripts/environment/hospital_geometry.gd"
## An open bus terminal on the proven city lanes. All station buildings,
## markings and vehicles are visual-only; ground and defense walls collide.

const WEST_BUS := Vector3(-19.5, 0, -68.5)
const EAST_BUS := Vector3(19.5, 0, -68.5)


func _ready() -> void:
	_setup_materials()
	(materials["concrete"] as StandardMaterial3D).albedo_color = Color(0.43, 0.46, 0.45)
	(materials["trim"] as StandardMaterial3D).albedo_color = Color(0.30, 0.34, 0.35)
	(materials["red"] as StandardMaterial3D).albedo_color = Color(0.19, 0.43, 0.49)
	(materials["road"] as StandardMaterial3D).albedo_color = Color(0.65, 0.65, 0.63)
	_textured("road", "terminal_asphalt", Vector3(18, 22, 1))
	materials["terminal_cladding"] = _material(Color(0.76, 0.78, 0.76), 0.15)
	_textured("terminal_cladding", "terminal_panel", Vector3(3, 2, 1))
	materials["terminal_frame"] = _material(Color(0.19, 0.23, 0.25), 0.25)
	materials["terminal_glass"] = _material(Color(0.09, 0.19, 0.22), 0.18)
	materials["terminal_teal"] = _material(Color(0.08, 0.38, 0.43))
	materials["terminal_yellow"] = _material(Color(0.68, 0.48, 0.16))
	materials["terminal_ivory"] = _material(Color(0.70, 0.69, 0.61))
	materials["terminal_marking"] = _material(Color(0.48, 0.47, 0.36))
	materials["terminal_hubs"] = _material(Color(0.43, 0.45, 0.42), 0.4)
	materials["terminal_lamp"] = _material(Color(0.91, 0.75, 0.43))
	var lamp: StandardMaterial3D = materials["terminal_lamp"]
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.58, 0.2)
	lamp.emission_energy_multiplier = 0.45
	_box("TerminalGround", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "road", true)
	_box("TerminalPlatform", Vector3(0, 1.9, 5), Vector3(31, 3.8, 16), "concrete", true)
	_box("TerminalPlatformTop", Vector3(0, 3.95, 5), Vector3(32, 0.1, 16), "concrete")
	_defenses()
	_terminal_architecture()
	_bus(WEST_BUS, "WestBus", "terminal_yellow")
	_bus(EAST_BUS, "EastBus", "terminal_ivory")


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
		_box("TerminalGateHeader%d" % side, Vector3(side * 16.7, 4.5, z), Vector3(0.8, 0.6, 8), "terminal_teal")
		for offset: float in [-3.7, 3.7]:
			_box("TerminalGatePost%d_%s" % [side, offset], Vector3(side * 16.7, 2.0, z + offset), Vector3(0.8, 4, 0.35), "concrete")


func _terminal_architecture() -> void:
	var cladding: Array[Transform3D] = []
	var frame: Array[Transform3D] = []
	var glass: Array[Transform3D] = []
	var signs: Array[Transform3D] = []
	var paint: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	# Arrival hall behind spawn points: glazed bays, broad roof and signboard.
	_detail(cladding, Vector3(0, 8.5, -153), Vector3(64, 17, 2.0))
	_detail(frame, Vector3(0, 17.5, -152.5), Vector3(67, 1.1, 5.0))
	_detail(signs, Vector3(0, 14.6, -151.85), Vector3(25, 2.8, 0.35))
	for x: float in [-26.0, -19.5, -13.0, -6.5, 0.0, 6.5, 13.0, 19.5, 26.0]:
		_detail(glass, Vector3(x, 7.0, -151.93), Vector3(5.7, 9.8, 0.12))
		_detail(frame, Vector3(x, 7.0, -151.78), Vector3(0.18, 9.8, 0.20))
		_detail(frame, Vector3(x, 4.1, -151.75), Vector3(5.7, 0.16, 0.22))
		_detail(lights, Vector3(x, 12.2, -151.65), Vector3(1.8, 0.23, 0.16))
	for x: float in [-9.0, 9.0]:
		_detail(frame, Vector3(x, 2.7, -151.65), Vector3(4.5, 5.2, 0.18))
		_detail(glass, Vector3(x, 2.9, -151.50), Vector3(3.8, 4.4, 0.10))
	# Two platform roofs and columns outside the central firing area. The
	# landmark canopies behind them continue the silhouette into the skyline.
	for side: int in [-1, 1]:
		var x: float = side * 26.5
		_detail(cladding, Vector3(x, 10.6, -110), Vector3(10, 0.7, 44))
		_detail(signs, Vector3(x - side * 5.1, 10.2, -110), Vector3(0.25, 1.0, 44))
		for z: float in [-125.0, -110.0, -95.0]:
			_detail(frame, Vector3(x - side * 4.2, 5.1, z), Vector3(0.45, 10.2, 0.45))
			_detail(frame, Vector3(x, 10.0, z), Vector3(10, 0.35, 0.4))
			_detail(lights, Vector3(x, 9.9, z + 0.3), Vector3(5, 0.15, 0.3))
		# Departure board and bench sit behind the routes on each platform.
		_detail(frame, Vector3(side * 30.5, 5.5, -108), Vector3(0.35, 10.8, 0.35))
		_detail(signs, Vector3(side * 30.5, 9.1, -107.7), Vector3(4.8, 2.1, 0.25))
		for row: int in 3:
			_detail(lights, Vector3(side * 30.5, 9.7 - row * 0.55, -107.52), Vector3(3.2, 0.12, 0.08))
		_detail(frame, Vector3(side * 29.0, 0.65, -116), Vector3(3.5, 0.3, 1.0))
		_detail(frame, Vector3(side * 29.0, 1.4, -116.45), Vector3(3.5, 1.2, 0.16))
		for i: int in 6:
			_detail(paint, Vector3(side * 11.0, 0.018, -54.0 - i * 10.0), Vector3(0.20, 0.025, 4.5))
	# Faded zebra stripes lie flush with the road and never hide enemies.
	for i: int in 9:
		_detail(paint, Vector3(-12.0 + i * 3.0, 0.02, -51), Vector3(1.3, 0.02, 3.0))
	_batch(self, "TerminalCladding", cladding, BoxMesh.new(), materials["terminal_cladding"])
	_batch(self, "TerminalFrame", frame, BoxMesh.new(), materials["terminal_frame"])
	_batch(self, "TerminalGlass", glass, BoxMesh.new(), materials["terminal_glass"])
	_batch(self, "TerminalSigns", signs, BoxMesh.new(), materials["terminal_teal"])
	_batch(self, "TerminalRoadMarks", paint, BoxMesh.new(), materials["terminal_marking"])
	_batch(self, "TerminalLights", lights, BoxMesh.new(), materials["terminal_lamp"])
	var title := Label3D.new()
	title.name = "TerminalHallSign"
	title.text = "TERMINAL"
	title.font = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	title.font_size = 96
	title.pixel_size = 0.020
	title.modulate = Color(0.90, 0.91, 0.84)
	title.position = Vector3(0, 14.65, -151.55)
	title.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(title)


## A pair of lightweight buses at the shoulders. Each uses five or six batches
## and has no collision; identical wheels and windows are instanced.
func _bus(at: Vector3, bus_name: String, body_color: String) -> void:
	var root := Node3D.new()
	root.name = bus_name
	root.position = at
	add_child(root)
	var body: Array[Transform3D] = []
	var trim: Array[Transform3D] = []
	var glass: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var tires: Array[Transform3D] = []
	var hubs: Array[Transform3D] = []
	_detail(body, Vector3(0, 2.05, 0), Vector3(3.6, 3.1, 7.8))
	_detail(body, Vector3(0, 3.7, 0), Vector3(3.7, 0.24, 7.9))
	_detail(trim, Vector3(0, 0.72, 0), Vector3(3.8, 0.42, 7.9))
	_detail(glass, Vector3(0, 2.75, 3.94), Vector3(3.05, 1.35, 0.12))
	_detail(trim, Vector3(0, 2.75, 4.02), Vector3(0.12, 1.35, 0.12))
	_detail(trim, Vector3(0, 3.58, 3.97), Vector3(2.9, 0.36, 0.15))
	_detail(lamps, Vector3(0, 3.58, 4.07), Vector3(1.9, 0.12, 0.08))
	_detail(trim, Vector3(0, 1.12, 4.03), Vector3(3.7, 0.26, 0.18))
	for y: float in [1.45, 1.58, 1.71]:
		_detail(trim, Vector3(0, y, 4.01), Vector3(1.4, 0.05, 0.10))
	for x: float in [-1.3, 1.3]:
		_detail(lamps, Vector3(x, 1.46, 4.04), Vector3(0.45, 0.30, 0.12))
		_detail(trim, Vector3(x * 1.4, 2.6, 3.1), Vector3(0.26, 0.46, 0.20))
		for z: float in [-2.7, 2.5]:
			var wheel_at := Vector3(signf(x) * 1.85, 0.72, z)
			tires.append(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), wheel_at))
			hubs.append(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), wheel_at + Vector3(signf(x) * 0.25, 0, 0)))
	for side: int in [-1, 1]:
		_detail(trim, Vector3(side * 1.83, 1.68, 0), Vector3(0.10, 0.32, 7.7))
		for z: float in [-2.65, -0.9, 0.85, 2.6]:
			_detail(glass, Vector3(side * 1.83, 2.7, z), Vector3(0.09, 1.3, 1.45))
		_detail(trim, Vector3(side * 1.88, 2.7, 1.75), Vector3(0.07, 1.65, 0.09))
	_detail(trim, Vector3(0, 2.1, -3.97), Vector3(3.3, 0.16, 0.10))
	_batch(root, "BusBody", body, BoxMesh.new(), materials[body_color])
	_batch(root, "BusTrim", trim, BoxMesh.new(), materials["terminal_frame"])
	_batch(root, "BusWindows", glass, BoxMesh.new(), materials["terminal_glass"])
	_batch(root, "BusLights", lamps, BoxMesh.new(), materials["terminal_lamp"])
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = 0.72
	tire_mesh.bottom_radius = 0.72
	tire_mesh.height = 0.42
	tire_mesh.radial_segments = 10
	_batch(root, "BusTires", tires, tire_mesh, materials["rubber"])
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.31
	hub_mesh.bottom_radius = 0.31
	hub_mesh.height = 0.07
	hub_mesh.radial_segments = 10
	_batch(root, "BusHubs", hubs, hub_mesh, materials["terminal_hubs"])


func _detail(items: Array[Transform3D], at: Vector3, dimensions: Vector3) -> void:
	items.append(Transform3D(Basis.from_scale(dimensions), at))


func _batch(parent: Node3D, batch_name: String, items: Array[Transform3D], mesh: PrimitiveMesh, material: Material) -> void:
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = items.size()
	for index: int in items.size():
		multi.set_instance_transform(index, items[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
