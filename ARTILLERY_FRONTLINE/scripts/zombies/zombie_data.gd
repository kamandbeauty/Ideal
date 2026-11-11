class_name ZombieData
extends Resource
## Tunable numbers of one zombie type. Balance lives in resources/zombies/*.tres.

@export var id: StringName = &"walker"
## Text key of the type's name (shown on the boss bar).
@export var name_key: String = "zombie_walker"
@export var scene: PackedScene
## How many painted skins exist for this type (assets/textures/zombies/zombie_<id>_a..).
@export_range(1, 3) var skins: int = 3
## Nodes built before the match so the first ones do not hitch.
@export_range(0, 80) var prewarm: int = 0
## A boss is announced, gets a health bar on the HUD, and its fall is celebrated.
@export var is_boss: bool = false

@export_group("Body")
@export_range(1.0, 100000.0, 1.0) var max_health: float = 80.0
@export_range(0.5, 3.0, 0.01) var scale_min: float = 0.95
@export_range(0.5, 3.0, 0.01) var scale_max: float = 1.06
## Share of a head hit's damage that gets through the skull (1 = the weapon's full headshot bonus).
@export_range(0.1, 2.0, 0.05) var head_damage_scale: float = 1.0
## Share of blast damage that gets through.
@export_range(0.0, 2.0, 0.05) var blast_damage_scale: float = 1.0

@export_group("Movement")
## Metres per second on open ground.
@export_range(0.2, 12.0, 0.05) var speed: float = 1.9
## Each zombie gets speed * (1 +/- this).
@export_range(0.0, 0.5, 0.01) var speed_variance: float = 0.14
## Ground speed at which the walk clip's feet do not slide.
@export_range(0.2, 12.0, 0.01) var stride_speed: float = 1.3
@export_range(1.0, 20.0, 0.5) var turn_speed: float = 6.0

@export_group("Reactions")
## Movement keeps this share of its speed for a moment after a hit (1 = hits do not slow it).
@export_range(0.0, 1.0, 0.05) var flinch_slow: float = 0.45
## One hit worth this share of its full health makes it stagger.
@export_range(0.05, 1.0, 0.05) var stagger_health_share: float = 0.3
## How long a blast leaves it reeling, against the blast's own stagger time (0 = never reels).
@export_range(0.0, 2.0, 0.05) var blast_reel_scale: float = 1.0
## How far a blast throws its body, against the blast's own knockback (0 = drops where it stood).
@export_range(0.0, 2.0, 0.05) var knockback_scale: float = 1.0

@export_group("Attack")
@export_range(0.0, 1000.0, 0.5) var attack_damage: float = 3.0
## Seconds per swing; the attack clip is retimed to match.
@export_range(0.2, 6.0, 0.05) var attack_interval: float = 1.1
## Point of the swing (0..1) where the blow lands.
@export_range(0.0, 1.0, 0.01) var attack_hit_point: float = 0.55
## Damage to the wall when one gets through a fallen gate.
@export_range(0.0, 2000.0, 1.0) var breach_damage: float = 25.0
## Places at the wall it takes up, side by side. Anything wider than one
## shoulders its way to the front and pushes aside whoever stood there.
@export_range(1, 4) var footprint: int = 1

@export_group("Hit volumes")
@export_range(0.1, 2.0, 0.01) var body_radius: float = 0.3
@export_range(0.5, 5.0, 0.01) var body_height: float = 1.45
@export_range(0.05, 1.0, 0.01) var head_radius: float = 0.2
## How far the trunk leans forward while it moves; the body volume leans with it.
@export_range(0.0, 45.0, 0.5) var body_lean_degrees: float = 10.0

@export_group("Voice")
## Groans, attack cries and death rattles are replayed at this pitch.
@export_range(0.3, 2.5, 0.05) var voice_pitch: float = 1.0
@export_range(-12.0, 12.0, 0.5) var voice_volume_db: float = 0.0
## Played once, everywhere, when one of these appears (empty for the rank and file).
@export var spawn_sound: String = ""
## Played instead of the common death rattles (empty to use them).
@export var death_sound: String = ""

@export_group("Remains")
@export_range(0.0, 30.0, 0.5) var corpse_time: float = 6.0


## Total height of the standing figure, from the hit volumes.
func height() -> float:
	return body_height + head_radius * 2.0
