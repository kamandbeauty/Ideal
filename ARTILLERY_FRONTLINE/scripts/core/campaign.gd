class_name Campaign
extends RefCounted
## The siege as the player meets it: a few short stages on the same wall, each
## a set of waves, each opened by winning the one before it.

const STAGES: Array[String] = [
	"res://resources/waves/stage_1_waves.tres",
	"res://resources/waves/stage_2_waves.tres",
	"res://resources/waves/stage_3_waves.tres",
]


static func count() -> int:
	return STAGES.size()


static func waves(stage: int) -> WaveSet:
	return load(STAGES[clampi(stage, 0, STAGES.size() - 1)]) as WaveSet


## How many stages may be started by a player who has won `cleared` of them: those, and the next.
static func open_stages(cleared: int) -> int:
	return clampi(cleared + 1, 1, STAGES.size())


## The stage and the wave in it (both counted from 1) of the `overall`-th wave of the whole siege.
static func place_of(overall: int) -> Vector2i:
	var left: int = maxi(overall, 1)
	for stage: int in STAGES.size():
		var size: int = waves(stage).waves.size()
		if left <= size or stage == STAGES.size() - 1:
			return Vector2i(stage + 1, mini(left, size))
		left -= size
	return Vector2i(1, 1)


static func total_waves() -> int:
	var sum: int = 0
	for stage: int in STAGES.size():
		sum += waves(stage).waves.size()
	return sum


static func total_zombies() -> int:
	var sum: int = 0
	for stage: int in STAGES.size():
		sum += waves(stage).total_zombies()
	return sum
