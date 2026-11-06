class_name WeaponConfig
extends Resource

@export var display_name: String = "M-70 BASTION"
@export var muzzle_velocity: float = 35.0
@export var damage_multiplier: float = 1.0
@export var effective_range: float = 145.0
@export_range(0.0, 1.0, 0.01) var accuracy: float = 0.98
@export var compatible_ammunition: PackedStringArray = ["he", "ap"]
@export var reload_seconds: float = 2.4
@export var min_elevation_degrees: float = 8.0
@export var max_elevation_degrees: float = 65.0
@export var traverse_degrees: float = 48.0
@export var gravity: float = 9.81
@export var drag: float = 0.0
