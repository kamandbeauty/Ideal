extends Node
## Autoload Events: the only channel between gameplay systems and the interface.

signal match_started
signal match_finished(victory: bool, stats: Dictionary)
signal wave_started(index: int, total: int)
signal wave_cleared(index: int, total: int)
signal intermission_started(seconds: float, next_index: int)
signal zombie_spawned(zombie: Node3D)
signal zombie_killed(zombie: Node3D, headshot: bool)
signal zombie_hit(position: Vector3, headshot: bool, lethal: bool)
signal wall_damaged(amount: float, health: float, max_health: float)
signal gate_damaged(amount: float, health: float, max_health: float)
signal gate_destroyed
signal wall_breached
## kind: gate_attack, wall_attack, gate_half, gate_critical, wall_half, wall_critical
signal defense_warning(kind: String)
signal weapon_fired(weapon: Node)
## The gunner took another weapon in hand.
signal weapon_changed(index: int, weapon: Node)
## The player asked for a weapon with nothing left to fire.
signal weapon_refused(index: int)
signal grenades_changed(count: int, capacity: int)
signal grenade_thrown(target: Vector3)
signal explosion(position: Vector3, radius: float, kills: int)
## Rockets and grenades handed over after a wave; only what actually fitted.
signal resupplied(rockets: int, grenades: int)
signal ammo_changed(ammo: int, magazine: int)
signal reload_started(duration: float)
signal reload_finished
signal settings_changed
signal language_changed
