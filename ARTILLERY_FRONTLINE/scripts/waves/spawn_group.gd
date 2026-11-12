class_name SpawnGroup
extends Resource
## One stream of zombies inside a wave.

## Zombie type id, matching a ZombieData resource.
@export var zombie: StringName = &"walker"
@export_range(1, 500) var count: int = 8
## Seconds after the wave starts before the first one appears.
@export_range(0.0, 600.0, 0.1) var start_time: float = 0.0
## Seconds between spawns.
@export_range(0.05, 60.0, 0.05) var interval: float = 1.5
## How many appear together at each spawn.
@export_range(1, 20) var burst: int = 1
## Route names to choose from; empty means any route of the level.
@export var routes: PackedStringArray = PackedStringArray()
## What they go for: "gate", "wall" or "any".
@export_enum("gate", "wall", "any") var target: String = "gate"
