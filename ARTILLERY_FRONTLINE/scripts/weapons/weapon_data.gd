class_name WeaponData
extends Resource
## Tunable numbers of one weapon. Balance lives in resources/weapons/*.tres.

@export var id: StringName = &"twin_hmg"
@export var name_key: String = "weapon_twin_hmg"

@export_group("Damage")
@export_range(1.0, 2000.0, 0.5) var damage: float = 34.0
@export_range(1.0, 10.0, 0.05) var headshot_multiplier: float = 2.5
## How many extra zombies a round may pass through, and what it keeps each time.
@export_range(0, 4) var penetration: int = 1
@export_range(0.0, 1.0, 0.05) var penetration_damage_scale: float = 0.6

@export_group("Fire")
## Seconds between rounds; the two barrels alternate.
@export_range(0.02, 3.0, 0.005) var fire_interval: float = 0.085
@export_range(100.0, 1500.0, 5.0) var muzzle_velocity: float = 720.0
@export_range(0.0, 5.0, 0.01) var spread_degrees: float = 0.3
@export_range(50.0, 1000.0, 5.0) var max_range: float = 420.0
## One round in this many shows a tracer; 1 traces every round.
@export_range(1, 10) var tracer_every: int = 2
## Bullets converge on the crosshair no closer than this.
@export_range(1.0, 100.0, 0.5) var min_convergence: float = 12.0

@export_group("Ammunition")
@export_range(1, 1000) var magazine_size: int = 160
@export_range(0.1, 10.0, 0.05) var reload_time: float = 2.6
@export var auto_reload: bool = true

@export_group("Feel")
@export_range(0.0, 4.0, 0.05) var recoil_scale: float = 1.0
@export_range(0.0, 0.2, 0.005) var barrel_travel: float = 0.05
