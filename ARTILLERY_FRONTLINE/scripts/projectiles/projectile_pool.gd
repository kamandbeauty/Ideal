class_name ProjectilePool
extends Node3D

signal impact(position: Vector3, normal: Vector3, collider: Object, ammunition: AmmunitionData, damage_scale: float, shot_id: int)
signal shell_expired
const CAPACITY: int = 12
var shells: Array[ArtilleryProjectile] = []
var active_shell: ArtilleryProjectile

func _ready() -> void:
	for index in range(CAPACITY):
		var shell := ArtilleryProjectile.new()
		shell.name = "Shell%02d" % index
		add_child(shell)
		shell.impacted.connect(_on_impact.bind(shell))
		shell.expired.connect(func(): shell_expired.emit())
		shells.append(shell)

func launch(origin: Vector3, velocity: Vector3, ammo: AmmunitionData, damage_scale: float = 1.0, shot_id: int = 0) -> bool:
	for shell in shells:
		if not shell.active:
			shell.launch(origin, velocity, ammo, damage_scale, shot_id)
			active_shell = shell
			return true
	return false

func _on_impact(position: Vector3, normal: Vector3, collider: Object, ammo: AmmunitionData, shell: ArtilleryProjectile) -> void:
	impact.emit(position, normal, collider, ammo, shell.damage_scale, shell.shot_id)

func active_count() -> int:
	var count: int = 0
	for shell in shells:
		if shell.active:
			count += 1
	return count

func clear() -> void:
	for shell in shells:
		shell.deactivate()
	active_shell = null
