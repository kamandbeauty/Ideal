class_name CoastalBackgroundAction
extends Node3D
## Low-cost distant battlefield activity: rotor wash, patrol armor and offshore boat.
var helicopter: Node3D
var rotor: Node3D
var boat: Node3D
var tank: Node3D
var clock: float = 0.0

func _ready() -> void:
	_build_helicopter()
	_build_boat()
	_build_tank()

func _build_helicopter() -> void:
	helicopter = Node3D.new()
	add_child(helicopter)
	var path: String = "res://assets/models/helicopter.glb"
	if ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		helicopter.add_child(model)
		MaterialLibrary.apply_to_model(model)
		rotor = model.find_child("Rotor", true, false) as Node3D
	else:
		MeshFactory.sphere(helicopter, "Fuselage", Vector3.ZERO, Vector3(1.4, 1.1, 3.2), Color(0.28, 0.32, 0.26), "paint_olive")
		MeshFactory.box(helicopter, "Tail", Vector3(0, 0.3, 4.2), Vector3(0.35, 0.35, 5.0), Color(0.28, 0.32, 0.26), true, "paint_olive")
		rotor = Node3D.new()
		rotor.position.y = 1.2
		helicopter.add_child(rotor)
		MeshFactory.box(rotor, "BladeA", Vector3.ZERO, Vector3(9.0, 0.06, 0.28), Color(0.12, 0.13, 0.12), false, "steel")
		MeshFactory.box(rotor, "BladeB", Vector3.ZERO, Vector3(0.28, 0.06, 9.0), Color(0.12, 0.13, 0.12), false, "steel")
	helicopter.position = Vector3(-160, 42, -120)

func _build_boat() -> void:
	boat = Node3D.new()
	add_child(boat)
	var path: String = "res://assets/models/patrol_boat.glb"
	if ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		boat.add_child(model)
		MaterialLibrary.apply_to_model(model)
	else:
		MeshFactory.box(boat, "Hull", Vector3(0, 0.4, 0), Vector3(2.4, 1.0, 7.5), Color(0.35, 0.38, 0.36), true, "paint_sand")
		MeshFactory.box(boat, "Cabin", Vector3(0, 1.2, 1.0), Vector3(1.6, 1.0, 2.0), Color(0.4, 0.42, 0.4), true, "paint_sand")
	boat.position = Vector3(95, 0.1, -110)

func _build_tank() -> void:
	tank = Node3D.new()
	add_child(tank)
	var path: String = "res://assets/models/warden.glb"
	if ResourceLoader.exists(path):
		var model: Node3D = load(path).instantiate()
		model.rotation.y = PI
		tank.add_child(model)
		MaterialLibrary.apply_to_model(model)
	else:
		MeshFactory.box(tank, "Hull", Vector3(0, 1.0, 0), Vector3(3.4, 1.6, 6.4), Color(0.3, 0.34, 0.24), true, "paint_olive")
	tank.position = Vector3(-70, CoastalTerrain.height_at(-70, 20), 20)

func tick(delta: float) -> void:
	clock += delta
	if helicopter:
		var t: float = fmod(clock * 0.045, 1.0)
		helicopter.position = Vector3(lerpf(-220.0, 220.0, t), 40.0 + sin(clock * 0.7) * 2.0, lerpf(-160.0, -90.0, t))
		helicopter.rotation.y = PI * 0.5
	if rotor:
		rotor.rotation.y += delta * 22.0
	if boat:
		boat.position.x = 95.0 + sin(clock * 0.08) * 28.0
		boat.position.y = 0.1 + sin(clock * 1.1) * 0.12
		boat.rotation.z = sin(clock * 0.9) * 0.03
	if tank:
		var patrol: float = sin(clock * 0.05) * 60.0
		tank.position.x = -70.0 + patrol
		tank.position.z = 18.0 + cos(clock * 0.05) * 8.0
		tank.position.y = CoastalTerrain.height_at(tank.position.x, tank.position.z)
		tank.rotation.y = PI * 0.5 + (0.0 if cos(clock * 0.05) >= 0.0 else PI)
