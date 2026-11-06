class_name Destructible
extends StaticBody3D
signal broken(target_id: String, position: Vector3)

var target_id: String = ""
var kind: String = "crate"
var health := HealthComponent.new()
var intact: Node3D
var wreck: Node3D
var sections: Array[Node3D] = []
var stage: int = 0
var size: Vector3 = Vector3(2.5, 2.5, 2.5)
var optional: bool = false

func configure(id: String, type: String, dimensions: Vector3) -> void:
	target_id = id
	kind = type
	size = dimensions
	collision_layer = 4
	collision_mask = 0
	health.maximum = 80.0 if kind == "crate" else 240.0
	add_child(health)
	health.changed.connect(_on_health_changed)
	health.destroyed.connect(_on_destroyed)
	intact = Node3D.new()
	intact.name = "Intact"
	add_child(intact)
	wreck = Node3D.new()
	wreck.name = "PrebuiltWreck"
	add_child(wreck)
	if kind == "crate":
		_build_crate()
	else:
		_build_section()
	wreck.visible = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)
	add_to_group("damageable")
	add_to_group("destructible")

func _build_crate() -> void:
	MeshFactory.box(intact, "TimberCore", Vector3(0, size.y * 0.5, 0), size, Color(0.72, 0.60, 0.42), true, "wood")
	for side in [-1.0, 1.0]:
		for offset in [-0.32, 0.32]:
			MeshFactory.box(intact, "SteelBand", Vector3(size.x * offset, size.y * 0.5, side * size.z * 0.505), Vector3(0.12, size.y + 0.04, 0.055), Color(0.42, 0.45, 0.40), true, "steel")
		MeshFactory.box(intact, "LidSlat", Vector3(0, size.y + 0.025, side * size.z * 0.25), Vector3(size.x + 0.06, 0.08, size.z * 0.43), Color(0.76, 0.64, 0.46), true, "wood")
	MeshFactory.box(intact, "HazardMark", Vector3(0, size.y * 0.6, -size.z * 0.515), Vector3(size.x * 0.38, size.y * 0.25, 0.03), Color(0.75, 0.38, 0.10))
	for index in range(5):
		var piece: MeshInstance3D = MeshFactory.box(wreck, "Splinter%d" % index, Vector3((index - 2) * 0.45, 0.15, sin(index * 2.0) * 0.6), Vector3(0.25, 0.22, 1.6), Color(0.48, 0.39, 0.27), true, "wood")
		piece.rotation.y = index * 1.7

func _build_section() -> void:
	var wall_color := Color(0.80, 0.76, 0.66)
	MeshFactory.box(intact, "WallLeft", Vector3(-size.x * 0.44, size.y * 0.5, 0), Vector3(size.x * 0.12, size.y, size.z), wall_color, true, "concrete")
	MeshFactory.box(intact, "WallRight", Vector3(size.x * 0.44, size.y * 0.5, 0), Vector3(size.x * 0.12, size.y, size.z), wall_color, true, "concrete")
	MeshFactory.box(intact, "WallBack", Vector3(0, size.y * 0.5, size.z * 0.44), Vector3(size.x, size.y, size.z * 0.12), wall_color, true, "concrete")
	var roof: MeshInstance3D = MeshFactory.box(intact, "BreakableRoof", Vector3(0, size.y, 0), Vector3(size.x + 0.4, 0.4, size.z + 0.4), Color(0.55, 0.57, 0.50), true, "steel")
	sections.append(roof)
	var front: MeshInstance3D = MeshFactory.box(intact, "BreakableFront", Vector3(0, size.y * 0.65, -size.z * 0.44), Vector3(size.x * 0.8, size.y * 0.7, 0.3), wall_color, true, "concrete")
	sections.append(front)
	MeshFactory.box(wreck, "Foundation", Vector3(0, 0.2, 0), Vector3(size.x, 0.4, size.z), Color(0.55, 0.52, 0.45), true, "concrete")
	for index in range(4):
		var rubble: MeshInstance3D = MeshFactory.box(wreck, "Rubble%d" % index, Vector3(sin(index * 2.1) * size.x * 0.3, 0.55, cos(index * 1.7) * size.z * 0.3), Vector3(1.8, 0.8, 1.2), wall_color.darkened(0.25), true, "concrete")
		rubble.rotation = Vector3(0.15 * index, index * 0.8, 0.12)

func damage_point() -> Vector3:
	return global_position + Vector3.UP * size.y * 0.45

func armor_value() -> float:
	return 0.0

func receive_damage(amount: float, _point: Vector3, _direct: bool) -> float:
	return health.apply_damage(amount)

func _on_health_changed(current: float, maximum: float) -> void:
	if current / maximum < 0.65 and stage == 0:
		stage = 1
		if not sections.is_empty():
			sections[0].visible = false
		elif intact.get_child_count() > 1:
			intact.get_child(1).visible = false

func _on_destroyed() -> void:
	stage = 2
	intact.visible = false
	wreck.visible = true
	collision_layer = 0
	set_deferred("collision_mask", 0)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	broken.emit(target_id, global_position)
