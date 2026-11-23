extends "res://scripts/environment/hospital_geometry.gd"
## Enclosed station: the far portal continues into a dark tunnel, while the
## two side doors coincide with the existing attack lines and breach plates.

var emergency_material: StandardMaterial3D
var emergency_clock: float = 0.0
## Decorative station failures: fixed schedule and existing pooled particles.
## They never obstruct, damage or alter any gameplay system.
var station_effects: EffectPool
var station_event_timer: float = 12.0
var station_event_count: int = 0
var last_station_event: String = ""
const VENT_POINTS: Array[Vector3] = [Vector3(-19.0, 4.2, -68.0), Vector3(19.0, 4.2, -68.0)]
const BREAKER_POINTS: Array[Vector3] = [Vector3(-19.0, 6.0, -86.0), Vector3(19.0, 6.0, -86.0)]


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
	materials["wet"] = _material(Color(0.28, 0.32, 0.31, 0.28), 0.12)
	(materials["wet"] as StandardMaterial3D).roughness = 0.25
	(materials["wet"] as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emergency_material = _material(Color(0.45, 0.025, 0.02))
	emergency_material.emission_enabled = true
	emergency_material.emission = Color(0.9, 0.03, 0.015)
	emergency_material.emission_energy_multiplier = 1.2
	materials["emergency"] = emergency_material
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
	_station_details()
	_station_machinery()


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


## Decorative details stay outside the existing attack paths and have no
## collision. Each material is batched into a single draw call.
func _station_details() -> void:
	var metal: Array[Transform3D] = []
	var panels: Array[Transform3D] = []
	var glass: Array[Transform3D] = []
	var warning: Array[Transform3D] = []
	var wet: Array[Transform3D] = []
	for side: int in [-1, 1]:
		# Broken escalators behind the court: stepped treads and two handrails.
		for step: int in 11:
			_detail(metal, Vector3(side * 34.5, 0.18 + step * 0.19, -51.0 - step * 0.7), Vector3(4.0, 0.18, 0.65))
		for offset: float in [-2.1, 2.1]:
			var rail := Transform3D(Basis(Vector3.RIGHT, -0.26).scaled(Vector3(0.18, 0.2, 8.2)), Vector3(side * 34.5 + offset, 1.6, -54.5))
			metal.append(rail)
		# Elevated abandoned control booth; its openings face the gunner.
		_detail(panels, Vector3(side * 33.8, 6.0, -77.0), Vector3(7.0, 0.35, 6.0))
		_detail(panels, Vector3(side * 33.8, 2.9, -79.8), Vector3(7.0, 5.8, 0.25))
		_detail(glass, Vector3(side * 33.8, 4.1, -73.9), Vector3(6.5, 2.2, 0.15))
		for post: float in [-3.2, 0.0, 3.2]:
			_detail(metal, Vector3(side * 33.8 + post, 3.5, -73.7), Vector3(0.22, 5.0, 0.2))
		# Utility pipes and dangling cable sections are high over the lanes.
		for z: float in [-110.0, -86.0, -62.0]:
			_detail(metal, Vector3(side * 35.7, 13.7, z), Vector3(0.2, 0.2, 21.0))
			_detail(metal, Vector3(side * 29.5, 14.7, z), Vector3(0.13, 3.6, 0.13))
			_detail(warning, Vector3(side * 29.3, 13.0, z), Vector3(0.35, 0.35, 0.35))
		for z: float in [-118.0, -96.0, -74.0, -52.0]:
			_detail(warning, Vector3(side * 30.0, 11.0, z), Vector3(0.3, 0.6, 1.2))
		# Slick reflective patches remain flush with the floor and do not collide.
		for index: int in 5:
			_detail(wet, Vector3(side * (10.0 + (index % 2) * 3.0), 0.008, -61.0 - index * 12.0), Vector3(3.2, 0.012, 5.0))
	_batch_details("MetroUtilityMetal", metal, "trim")
	_batch_details("MetroBoothPanels", panels, "concrete")
	_batch_details("MetroBoothGlass", glass, "glass")
	_batch_details("MetroEmergencyIndicators", warning, "emergency")
	_batch_details("MetroWetFloor", wet, "wet")


## A pair of damaged vent cabinets and circuit boxes, on the shoulders of
## the station rather than across the firing lanes. They are purely visual.
func _station_machinery() -> void:
	var housings: Array[Transform3D] = []
	var grilles: Array[Transform3D] = []
	var indicators: Array[Transform3D] = []
	for side: int in [-1, 1]:
		var x: float = 19.0 * float(side)
		_detail(housings, Vector3(x, 4.1, -68.4), Vector3(2.7, 2.0, 0.3))
		for slat: int in 5:
			_detail(grilles, Vector3(x, 3.45 + float(slat) * 0.3, -68.22), Vector3(2.1, 0.09, 0.08))
		_detail(housings, Vector3(x, 6.0, -86.4), Vector3(1.8, 1.7, 0.3))
		_detail(indicators, Vector3(x, 6.0, -86.2), Vector3(0.6, 0.45, 0.1))
	_batch_details("MetroMachineryHousings", housings, "trim")
	_batch_details("MetroVentGrilles", grilles, "concrete")
	_batch_details("MetroCircuitIndicators", indicators, "emergency")


func setup_station_events(pool: EffectPool) -> void:
	station_effects = pool


func start_station_events() -> void:
	station_event_timer = 12.0
	station_event_count = 0
	last_station_event = ""


## Called only while the match is running. One small puff or spark at a time;
## bounded pooled emitters, no physics, no artificial light and no hazards.
## The low-quality tier skips ambient particles to protect frame time.
func step_station_events(delta: float) -> void:
	if station_effects == null:
		return
	station_event_timer -= maxf(delta, 0.0)
	if station_event_timer > 0.0:
		return
	var sequence: int = station_event_count
	station_event_count += 1
	if sequence % 2 == 0:
		last_station_event = "vent"
		station_event_timer = 20.0
		if station_effects.detail:
			station_effects.burst("smoke", to_global(VENT_POINTS[(sequence / 2) % 2]), Vector3.UP, 0.38)
	else:
		last_station_event = "circuit"
		station_event_timer = 24.0
		if station_effects.detail:
			station_effects.burst("spark", to_global(BREAKER_POINTS[(sequence / 2 + 1) % 2]), Vector3.DOWN, 0.8)


func _detail(target: Array[Transform3D], at: Vector3, dimensions: Vector3) -> void:
	target.append(Transform3D(Basis.IDENTITY.scaled(dimensions), at))


func _batch_details(batch_name: String, instances: Array[Transform3D], material_key: String) -> void:
	var mesh: PrimitiveMesh
	if material_key == "wet":
		var puddle := CylinderMesh.new()
		puddle.top_radius = 0.5
		puddle.bottom_radius = 0.5
		puddle.height = 1.0
		puddle.radial_segments = 12
		mesh = puddle
	else:
		mesh = BoxMesh.new()
	mesh.material = materials[material_key]
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = instances.size()
	for index: int in instances.size():
		batch.set_instance_transform(index, instances[index])
	var node := MultiMeshInstance3D.new()
	node.name = batch_name
	node.multimesh = batch
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _process(delta: float) -> void:
	# Cheap emissive flicker: no shadow maps, extra lights or per-lamp scripts.
	if emergency_material == null:
		return
	emergency_clock += delta
	var flicker: float = 0.35 if sin(emergency_clock * 9.0) > 0.94 else 1.0
	emergency_material.emission_energy_multiplier = 1.2 * flicker
