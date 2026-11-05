class_name HealthComponent
extends Node

signal changed(current: float, maximum: float)
signal destroyed

@export var maximum: float = 100.0
var current: float = 100.0
var is_destroyed: bool = false

func _ready() -> void:
	current = maximum

func apply_damage(amount: float) -> float:
	if is_destroyed or amount <= 0.0:
		return 0.0
	var applied: float = minf(current, amount)
	current = maxf(0.0, current - applied)
	changed.emit(current, maximum)
	if is_zero_approx(current):
		is_destroyed = true
		destroyed.emit()
	return applied
