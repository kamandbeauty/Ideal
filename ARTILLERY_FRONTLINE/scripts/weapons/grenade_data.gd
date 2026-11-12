class_name GrenadeData
extends Resource
## Tunable numbers of the hand grenade. Balance lives in resources/weapons/frag_grenade.tres.

@export var id: StringName = &"frag_grenade"
@export var name_key: String = "grenade"

@export_group("Supply")
## Grenades on the belt when a match starts, and the most it can hold.
@export_range(0, 20) var carried: int = 3
@export_range(1, 20) var capacity: int = 5
## Seconds between two throws.
@export_range(0.0, 10.0, 0.05) var cooldown: float = 1.0

@export_group("Throw")
## Nearest and farthest landing point, measured along the ground from the gunner.
@export_range(1.0, 30.0, 0.5) var min_range: float = 6.0
@export_range(5.0, 120.0, 0.5) var max_range: float = 46.0
## Ground speed of the lob; together with the distance it sets the time of flight.
@export_range(4.0, 60.0, 0.5) var throw_speed: float = 20.0
## The shortest flight keeps even a near throw rising out of the hand, clear of the parapet.
@export_range(0.2, 4.0, 0.05) var min_flight_time: float = 1.25
@export_range(0.2, 6.0, 0.05) var max_flight_time: float = 2.4
@export_range(1.0, 30.0, 0.1) var gravity: float = 9.8

@export_group("Fuze")
## The fuze burns this long after the grenade first touches down.
@export_range(0.0, 5.0, 0.05) var fuse_after_landing: float = 0.45
## It goes off after this long whatever happens.
@export_range(0.5, 12.0, 0.1) var max_life: float = 6.0
## Share of the speed kept across the surface and along its normal at each
## bounce. A low roll keeps the burst near the spot the player aimed at.
@export_range(0.0, 1.0, 0.01) var roll: float = 0.18
@export_range(0.0, 0.9, 0.01) var bounce: float = 0.28
@export var explosion: ExplosionData
