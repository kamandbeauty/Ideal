class_name WeaponData
extends Resource

@export var id: String = "kestrel"
@export var display_name: String = "KESTREL M-42"
@export var caliber: String = "155 mm"
@export var damage: float = 100.0
@export var muzzle_velocity: float = 82.0
@export var effective_range: float = 650.0
@export var reload_duration: float = 3.4
@export var accuracy_degrees: float = 0.35
@export var elevation_limits: Vector2 = Vector2(4.0, 72.0)
@export var traverse_limits: Vector2 = Vector2(-52.0, 52.0)
@export var compatible_ammunition: Array[String] = ["he", "ap"]
@export var magazine_capacity: int = 24
@export var model_path: String = "res://assets/models/kestrel.glb"
