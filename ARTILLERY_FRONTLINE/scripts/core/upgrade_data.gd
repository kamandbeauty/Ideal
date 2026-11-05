class_name UpgradeData
extends Resource

@export var id: String = "damage"
@export var display_name: String = "BARREL LINING"
@export var description: String = "+8% impact damage per level"
@export var maximum_level: int = 4
@export var base_cost: int = 160
@export var cost_step: int = 120
@export var points_per_level: int = 1

func cost(level: int) -> int:
	return base_cost + cost_step * level
