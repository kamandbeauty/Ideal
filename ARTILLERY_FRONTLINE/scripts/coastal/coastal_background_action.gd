class_name CoastalBackgroundAction
extends Node3D
## Cheap distant activity that is not part of the kill counter: offshore patrol boat.
var boat: Node3D
var clock: float = 0.0

func _ready() -> void:
	_build_boat()

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

func tick(delta: float) -> void:
	clock += delta
	if boat:
		boat.position.x = 95.0 + sin(clock * 0.08) * 28.0
		boat.position.y = 0.1 + sin(clock * 1.1) * 0.12
		boat.rotation.z = sin(clock * 0.9) * 0.03
