class_name LandingCraft
extends Node3D
## Moving amphibious landing craft; delivers infantry to the beachhead.
signal arrived(craft: LandingCraft)
var start: Vector3 = Vector3.ZERO
var destination: Vector3 = Vector3.ZERO
var progress: float = 0.0
var speed: float = 0.055
var ramp: Node3D
var model_root: Node3D
var has_arrived: bool = false
var bob_clock: float = 0.0

func configure(from: Vector3, to: Vector3) -> void:
	start = from
	destination = to
	global_position = from

func _ready() -> void:
	var path: String = "res://assets/models/landing_craft.glb"
	if ResourceLoader.exists(path):
		model_root = load(path).instantiate()
		add_child(model_root)
		MaterialLibrary.apply_to_model(model_root)
		ramp = model_root.find_child("Ramp", true, false) as Node3D
	if model_root == null:
		model_root = Node3D.new()
		add_child(model_root)
		MeshFactory.box(model_root, "Hull", Vector3(0, 0.8, 0), Vector3(4.2, 1.6, 11.5), Color(0.45, 0.48, 0.42), true, "paint_sand")
		MeshFactory.box(model_root, "Superstructure", Vector3(0, 2.0, 3.6), Vector3(2.6, 1.6, 2.4), Color(0.5, 0.52, 0.46), true, "paint_sand")
		ramp = Node3D.new()
		ramp.name = "Ramp"
		ramp.position = Vector3(0, 0.8, -5.7)
		model_root.add_child(ramp)
		MeshFactory.box(ramp, "RampPlate", Vector3(0, 0, -1.5), Vector3(3.6, 0.18, 3.0), Color(0.4, 0.42, 0.38), true, "steel")

func tick(delta: float) -> void:
	bob_clock += delta
	if not has_arrived:
		progress = minf(1.0, progress + speed * delta)
		var point: Vector3 = start.lerp(destination, progress)
		point.y = maxf(0.08, CoastalTerrain.height_at(point.x, point.z) + 0.15) + sin(bob_clock * 1.4) * 0.08
		global_position = point
		var direction: Vector3 = (destination - start).normalized()
		rotation.y = atan2(direction.x, direction.z)
		if progress >= 1.0:
			has_arrived = true
			arrived.emit(self)
	if ramp and has_arrived:
		ramp.rotation.x = lerpf(ramp.rotation.x, -1.25, delta * 1.5)
