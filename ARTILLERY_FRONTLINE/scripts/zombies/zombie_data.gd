class_name ZombieData
extends Resource
## Tunable numbers of one zombie type. Balance lives in resources/zombies/*.tres.

@export var id: StringName = &"walker"
@export var scene: PackedScene
## How many painted skins exist for this type (assets/textures/zombies/zombie_<id>_a..).
@export_range(1, 3) var skins: int = 3

@export_group("Body")
@export_range(1.0, 100000.0, 1.0) var max_health: float = 80.0
@export_range(0.5, 3.0, 0.01) var scale_min: float = 0.95
@export_range(0.5, 3.0, 0.01) var scale_max: float = 1.06

@export_group("Movement")
## Metres per second on open ground.
@export_range(0.2, 12.0, 0.05) var speed: float = 1.9
## Each zombie gets speed * (1 +/- this).
@export_range(0.0, 0.5, 0.01) var speed_variance: float = 0.14
## Ground speed at which the walk clip's feet do not slide.
@export_range(0.2, 12.0, 0.01) var stride_speed: float = 1.3
@export_range(1.0, 20.0, 0.5) var turn_speed: float = 6.0
## Movement keeps this share of its speed for a moment after a hit.
@export_range(0.0, 1.0, 0.05) var flinch_slow: float = 0.45

@export_group("Attack")
@export_range(0.0, 1000.0, 0.5) var attack_damage: float = 3.0
## Seconds per swing; the attack clip is retimed to match.
@export_range(0.2, 6.0, 0.05) var attack_interval: float = 1.1
## Point of the swing (0..1) where the blow lands.
@export_range(0.0, 1.0, 0.01) var attack_hit_point: float = 0.55
## Damage to the wall when one gets through a fallen gate.
@export_range(0.0, 2000.0, 1.0) var breach_damage: float = 25.0

@export_group("Hit volumes")
@export_range(0.1, 2.0, 0.01) var body_radius: float = 0.3
@export_range(0.5, 5.0, 0.01) var body_height: float = 1.45
@export_range(0.05, 1.0, 0.01) var head_radius: float = 0.2

@export_group("Remains")
@export_range(0.0, 30.0, 0.5) var corpse_time: float = 6.0
