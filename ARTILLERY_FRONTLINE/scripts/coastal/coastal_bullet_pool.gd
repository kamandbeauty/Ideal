class_name CoastalBulletPool
extends Node3D
signal impacted(position: Vector3, normal: Vector3, collider: Object, damage: float, blast: float)
const CAPACITY: int = 72
var bullets: Array[CoastalBullet] = []

func _ready() -> void:
	for index in range(CAPACITY):
		var bullet := CoastalBullet.new()
		bullet.name = "Tracer%02d" % index
		add_child(bullet)
		bullet.impacted.connect(_on_impact)
		bullets.append(bullet)

func launch(origin: Vector3, velocity: Vector3, damage: float, blast: float, collision_mask: int = 7, exclude: Array[RID] = []) -> bool:
	for bullet in bullets:
		if not bullet.active:
			bullet.launch(origin, velocity, damage, blast, collision_mask, exclude)
			return true
	return false

func _on_impact(position: Vector3, normal: Vector3, collider: Object, damage: float, blast: float) -> void:
	impacted.emit(position, normal, collider, damage, blast)

func active_count() -> int:
	var count: int = 0
	for bullet in bullets:
		if bullet.active:
			count += 1
	return count

func clear() -> void:
	for bullet in bullets:
		bullet.deactivate()
