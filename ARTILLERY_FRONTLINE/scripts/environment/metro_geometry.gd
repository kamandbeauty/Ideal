extends "res://scripts/environment/hospital_geometry.gd"
## Enclosed station: the far portal continues into a dark tunnel, while the
## two side doors coincide with the existing attack lines and breach plates.

func is_underground() -> bool:
	return true


func _ready() -> void:
	_setup_materials()
	_textured("wall", "metro_wall_detail", Vector3(8, 2, 1))
	materials["tunnel_dark"] = _material(Color(0.018, 0.023, 0.025))
	(materials["tunnel_dark"] as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials["train_body"] = _material(Color(0.82, 0.82, 0.78), 0.15)
	_textured("train_body", "metro_train_detail", Vector3(5, 1, 1))
	materials["sandbag"] = _material(Color(0.36, 0.32, 0.24))
	_textured("sandbag", "burlap", Vector3(2, 1, 1))
	_metro_defenses()
	_box("MetroFloor", Vector3(0, -0.25, -77), Vector3(150, 0.5, 190), "concrete", true)
	# The gun and player stand on the protected side of a continuous sandbag line.
	_box("FiringPlatform", Vector3(0, 1.9, 5), Vector3(31, 3.8, 16), "concrete", true)
	_box("PlatformTop", Vector3(0, 3.94, 5), Vector3(32, 0.12, 16), "concrete")
	_sandbags()
	# The opening is real geometry, not a black rectangle laid on a solid wall.
	_box("TunnelWest", Vector3(-29.5, 10, -136), Vector3(19, 20, 3), "wall", true)
	_box("TunnelEast", Vector3(29.5, 10, -136), Vector3(19, 20, 3), "wall", true)
	_box("TunnelLintel", Vector3(0, 17, -136), Vector3(40, 6, 3), "wall", true)
	_box("TunnelEnd", Vector3(0, 7, -166), Vector3(40, 14, 1), "tunnel_dark", true)
	_box("TunnelLeft", Vector3(-20, 7, -151), Vector3(1, 14, 30), "trim")
	_box("TunnelRight", Vector3(20, 7, -151), Vector3(1, 14, 30), "trim")
	_box("TunnelCeiling", Vector3(0, 14.2, -151), Vector3(40, 0.6, 30), "trim")
	for side: int in [-1, 1]:
		_box("StationSide%d" % side, Vector3(side * 38.5, 9, -70), Vector3(1, 18, 132), "wall")
	_box("Ceiling", Vector3(0, 18.5, -70), Vector3(77, 1, 132), "concrete")
	for index: int in 10:
		var z: float = -18.0 - index * 12.0
		_box("CeilingBeam%d" % index, Vector3(0, 17.8, z), Vector3(77, 0.8, 0.8), "trim")
		for side: int in [-1, 1]:
			_box("PlatformColumn%d_%d" % [side, index], Vector3(side * 30, 8.5, z), Vector3(1.0, 17, 1.0), "concrete")
			_box("EmergencyLight%d_%d" % [side, index], Vector3(side * 24, 17.3, z), Vector3(2.0, 0.16, 0.35), "white")
	for side: int in [-1, 1]:
		var x: float = side * 25.0
		_box("TrainBody%d" % side, Vector3(x, 3, -94), Vector3(6, 6, 51), "train_body")
		_box("TrainRoof%d" % side, Vector3(x, 6.2, -94), Vector3(6.2, 0.5, 51), "trim")
		_box("TrainStripe%d" % side, Vector3(x - side * 3.04, 2.5, -94), Vector3(0.12, 0.6, 50), "red")
		for index: int in 6:
			var z: float = -115.0 + index * 7.5
			_box("TrainWindow%d_%d" % [side, index], Vector3(x - side * 3.06, 4.1, z), Vector3(0.13, 1.5, 4), "glass")
			_box("TrainDoor%d_%d" % [side, index], Vector3(x - side * 3.08, 2.6, z + 3.0), Vector3(0.14, 4.1, 0.2), "trim")
		_box("PlatformEdge%d" % side, Vector3(side * 20.8, 0.08, -94), Vector3(0.35, 0.12, 50), "yellow")
	for x: float in [-4.5, -2.5, 2.5, 4.5]:
		_box("Rail%s" % x, Vector3(x, 0.08, -104), Vector3(0.16, 0.15, 112), "trim")
	for index: int in 31:
		_box("Sleeper%d" % index, Vector3(0, 0.03, -52 - index * 3), Vector3(10, 0.08, 0.35), "trim")
	_box("StationSign", Vector3(0, 15.5, -134.1), Vector3(14, 1.2, 0.2), "red")


func _metro_defenses() -> void:
	_wall_segment("WestWallFar", -16.8, -39.0, 18.0)
	_wall_segment("WestWallNear", -16.8, -12.0, 22.0)
	_wall_segment("EastWallFar", 16.65, -35.25, 25.5)
	_wall_segment("EastWallNear", 16.65, -7.0, 17.0)
	_box("WallPatch", Vector3(-16.8, 1.9, -26.5), Vector3(0.6, 3.8, 7), "trim")
	_box("GateLeafA", Vector3(16.65, 2.1, -20.75), Vector3(0.4, 4.2, 3.5), "trim")
	_box("GateLeafB", Vector3(16.65, 2.1, -17.25), Vector3(0.4, 4.2, 3.5), "trim")
	for side: int in [-1, 1]:
		var z: float = -26.5 if side < 0 else -19.0
		_box("MetalDoorHeader%d" % side, Vector3(side * 16.7, 4.5, z), Vector3(0.8, 0.5, 8), "yellow")
		for dz: float in [-3.7, 3.7]:
			_box("MetalDoorFrame%d_%s" % [side, dz], Vector3(side * 16.7, 2.0, z + dz), Vector3(0.8, 4.0, 0.35), "trim")


func _sandbags() -> void:
	# Repeated sack geometry is batched: two staggered rows, one draw call.
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.27
	mesh.height = 1.4
	mesh.material = materials["sandbag"]
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = 44
	for row: int in 2:
		for col: int in 22:
			var x: float = -14.7 + col * 1.4 + 0.35 * row
			batch.set_instance_transform(row * 22 + col, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, 4.18 + row * 0.42, -3.8)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "SandbagLine"
	instance.multimesh = batch
	add_child(instance)
