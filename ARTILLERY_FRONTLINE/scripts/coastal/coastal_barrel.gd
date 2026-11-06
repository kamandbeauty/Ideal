class_name CoastalBarrel
extends StaticBody3D
signal exploded(point: Vector3, radius: float)
var health: float = 35.0
var radius: float = 7.0
var destroyed: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("damageable")
	add_to_group("destructible")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.45
	cylinder.height = 1.15
	shape.shape = cylinder
	shape.position.y = 0.58
	add_child(shape)
	MeshFactory.cylinder(self, "Barrel", Vector3(0, 0.58, 0), 0.45, 1.15, Color(0.65, 0.32, 0.18), 20, "paint_olive")
	MeshFactory.cylinder(self, "BarrelRing", Vector3(0, 0.95, 0), 0.47, 0.07, Color(0.4, 0.4, 0.36), 20, "steel")
	MeshFactory.box(self, "Hazard", Vector3(0, 0.62, -0.46), Vector3(0.4, 0.3, 0.02), Color(0.8, 0.55, 0.12), true, "warning")

func receive_damage(amount: float) -> void:
	if destroyed:
		return
	health -= amount
	if health <= 0.0:
		destroyed = true
		collision_layer = 0
		exploded.emit(global_position + Vector3.UP * 0.6, radius)
		queue_free()
