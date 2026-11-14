class_name ExplosionData
extends Resource
## Area damage of one kind of blast. Balance lives in resources/explosions/*.tres.

@export_group("Damage")
## Damage at the centre.
@export_range(0.0, 5000.0, 1.0) var damage: float = 220.0
## Everything inside this radius takes the full damage.
@export_range(0.0, 20.0, 0.1) var inner_radius: float = 1.2
## Nothing beyond this radius is touched.
@export_range(0.5, 40.0, 0.1) var radius: float = 5.5
## Share of the damage that still arrives at the very edge.
@export_range(0.0, 1.0, 0.01) var edge_fraction: float = 0.15
## Damage to the gate or the wall when they stand inside the blast. 0 spares them.
@export_range(0.0, 1000.0, 1.0) var structure_damage: float = 0.0

@export_group("Reaction")
## How long a survivor reels when caught at the centre (seconds).
@export_range(0.0, 4.0, 0.05) var stagger_time: float = 0.9
## How far a body is thrown from the centre (metres).
@export_range(0.0, 10.0, 0.1) var knockback: float = 2.4

@export_group("Feel")
@export_range(0.2, 4.0, 0.05) var visual_scale: float = 1.0
## Camera jolt in degrees for a blast ten metres from the gunner; it fades with distance.
@export_range(0.0, 8.0, 0.1) var shake_degrees: float = 1.4
@export var sound: String = "explosion"
## Quieter blast clip used by smaller charges: "explosion_small".
@export_range(-30.0, 12.0, 0.5) var volume_db: float = 2.0


## 1 inside the inner radius, falling in a straight line to `edge_fraction` at
## the outer radius, and 0 beyond it.
func falloff(distance: float) -> float:
	if distance > radius:
		return 0.0
	if distance <= inner_radius or radius <= inner_radius:
		return 1.0
	var along: float = (distance - inner_radius) / (radius - inner_radius)
	return lerpf(1.0, edge_fraction, along)


func damage_at(distance: float) -> float:
	return damage * falloff(distance)


## The farthest distance at which the blast still does `amount` of damage.
func reach_for(amount: float) -> float:
	if amount <= 0.0 or damage <= 0.0:
		return radius
	var share: float = amount / damage
	if share > 1.0:
		return 0.0
	if share <= edge_fraction or radius <= inner_radius:
		return radius
	return inner_radius + (radius - inner_radius) * (1.0 - share) / (1.0 - edge_fraction)
