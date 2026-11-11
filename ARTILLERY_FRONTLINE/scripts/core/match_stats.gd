class_name MatchStats
extends RefCounted
## What happened in one match; shown on the result screen and folded into the profile.

## Machine-gun rounds fired and landed; explosives are counted apart so they cannot distort the accuracy.
var shots: int = 0
var hits: int = 0
var rockets: int = 0
var grenades: int = 0
var blast_kills: int = 0
## Kills of anything tougher than a walker, and of bosses among them.
var special_kills: int = 0
var bosses: int = 0
var kills: int = 0
var headshots: int = 0
var time: float = 0.0
## Highest wave reached, counted from 1.
var wave: int = 0
var waves_total: int = 0
var waves_cleared: int = 0
var victory: bool = false
var wall_left: float = 1.0
var gate_left: float = 1.0


func accuracy() -> float:
	return float(hits) / float(shots) if shots > 0 else 0.0


func to_dict() -> Dictionary:
	return {
		"shots": shots, "hits": hits, "kills": kills, "headshots": headshots, "time": time, "wave": wave, "waves_total": waves_total,
		"waves_cleared": waves_cleared, "victory": victory, "wall_left": wall_left, "gate_left": gate_left, "accuracy": accuracy(),
		"rockets": rockets, "grenades": grenades, "blast_kills": blast_kills, "special_kills": special_kills, "bosses": bosses,
	}
