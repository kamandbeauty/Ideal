class_name ProjectilePool
extends Node3D

signal impacted(point: Vector3, collider: Object, ammo: AmmoConfig)

const CAPACITY: int = 6
var projectiles: Array[ShellProjectile] = []


func _ready() -> void:
	for i in range(CAPACITY):
		var projectile := ShellProjectile.new()
		projectile.name = "Shell%02d" % i
		add_child(projectile)
		projectile.impacted.connect(_on_impact)
		projectiles.append(projectile)


func spawn(
	origin: Vector3, velocity: Vector3, ammo: AmmoConfig, gravity: float, drag: float
) -> ShellProjectile:
	for projectile in projectiles:
		if not projectile.active:
			projectile.launch(origin, velocity, ammo, gravity, drag)
			return projectile
	return null


func _on_impact(
	_projectile: ShellProjectile, point: Vector3, collider: Object, ammo: AmmoConfig
) -> void:
	impacted.emit(point, collider, ammo)
