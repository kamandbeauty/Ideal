class_name DefenseData
extends Resource
## Strength of the wall and its gate.

@export_range(1.0, 100000.0, 1.0) var wall_max_health: float = 1000.0
@export_range(1.0, 100000.0, 1.0) var gate_max_health: float = 700.0
## Fractions of health at which the HUD raises its warnings.
@export_range(0.0, 1.0, 0.01) var half_threshold: float = 0.5
@export_range(0.0, 1.0, 0.01) var critical_threshold: float = 0.25
## A target must be left alone this long before "under attack" is announced again.
@export_range(1.0, 120.0, 1.0) var attack_warning_cooldown: float = 8.0
