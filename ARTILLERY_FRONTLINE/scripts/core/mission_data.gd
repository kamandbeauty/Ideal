class_name MissionData
extends Resource

@export var id: String = "sr01"
@export var title: String = "FIRST LIGHT"
@export var subtitle: String = "Sable Ridge / Forward observation"
@export_multiline var briefing: String = "Neutralize the observation post."
@export var sector: String = "A1"
@export var difficulty: int = 1
@export var target_ids: Array[String] = []
@export var optional_crate_id: String = ""
@export var ammunition: Dictionary = {"he": 12, "ap": 6}
@export var time_limit: float = 240.0
@export var par_time: float = 90.0
@export var base_reward: int = 250
@export var unlock_after: String = ""
@export var map_position: Vector2 = Vector2(0.2, 0.6)
