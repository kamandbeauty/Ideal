class_name EnemyData
extends Resource

@export var id: String = "tank"
@export var display_name: String = "WARDEN MBT"
@export_enum("emplacement", "tank", "transport") var kind: String = "tank"
@export var health: float = 180.0
@export var armor: float = 0.18
@export var speed: float = 5.0
@export var collision_size: Vector3 = Vector3(5.8, 3.2, 9.0)
@export var score_value: int = 100
@export var model_path: String = "res://assets/models/warden.glb"
