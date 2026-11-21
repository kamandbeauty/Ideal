class_name Campaign
extends RefCounted
## Thirty stages in ten districts, each with its own wave set; all remain selectable.

const STAGES: Array[String] = [
	"res://resources/waves/stage_1_waves.tres",
	"res://resources/waves/stage_2_waves.tres",
	"res://resources/waves/stage_3_waves.tres",
	"res://resources/waves/stage_4_waves.tres",
	"res://resources/waves/stage_5_waves.tres",
	"res://resources/waves/stage_6_waves.tres",
	"res://resources/waves/stage_7_waves.tres",
	"res://resources/waves/stage_8_waves.tres",
	"res://resources/waves/stage_9_waves.tres",
	"res://resources/waves/stage_10_waves.tres",
	"res://resources/waves/stage_11_waves.tres",
	"res://resources/waves/stage_12_waves.tres",
	"res://resources/waves/stage_13_waves.tres",
	"res://resources/waves/stage_14_waves.tres",
	"res://resources/waves/stage_15_waves.tres",
	"res://resources/waves/stage_16_waves.tres",
	"res://resources/waves/stage_17_waves.tres",
	"res://resources/waves/stage_18_waves.tres",
	"res://resources/waves/stage_19_waves.tres",
	"res://resources/waves/stage_20_waves.tres",
	"res://resources/waves/stage_21_waves.tres",
	"res://resources/waves/stage_22_waves.tres",
	"res://resources/waves/stage_23_waves.tres",
	"res://resources/waves/stage_24_waves.tres",
	"res://resources/waves/stage_25_waves.tres",
	"res://resources/waves/stage_26_waves.tres",
	"res://resources/waves/stage_27_waves.tres",
	"res://resources/waves/stage_28_waves.tres",
	"res://resources/waves/stage_29_waves.tres",
	"res://resources/waves/stage_30_waves.tres",

]


static func count() -> int:
	return STAGES.size()


static func waves(stage: int) -> WaveSet:
	return load(STAGES[clampi(stage, 0, STAGES.size() - 1)]) as WaveSet


## The first three districts have dedicated layouts. Later districts reuse the
## city routes and defenses with distinct, collision-free skyline landmarks.
static func scene(stage: int) -> String:
	if stage >= 6 and stage < 9:
		return "res://scenes/levels/metro_siege.tscn"
	if stage >= 3 and stage < 6:
		return "res://scenes/levels/hospital_siege.tscn"
	return "res://scenes/levels/city_siege.tscn"


static func district(stage: int) -> int:
	return clampi(stage, 0, count() - 1) / 3


## City and hospital use identical base health. From metro onward, each
## district is 20 percent tougher than the district before it. Wave numbers
## do not add extra health; this preserves the opening six stages' hit counts.
static func zombie_health_scale(stage: int) -> float:
	return pow(1.2, maxi(district(stage) - 1, 0))


## All stages are available regardless of the saved number of wins.
static func open_stages(_cleared: int) -> int:
	return STAGES.size()


## The stage and the wave in it (both counted from 1) of the `overall`-th wave of the whole siege.
static func place_of(overall: int) -> Vector2i:
	var left: int = maxi(overall, 1)
	for stage: int in STAGES.size():
		var size: int = waves(stage).waves.size()
		if left <= size or stage == STAGES.size() - 1:
			return Vector2i(stage + 1, mini(left, size))
		left -= size
	return Vector2i(1, 1)


## The whole siege as one set: every wave of every stage, in order. For the balance record and the tests;
## the game itself plays one stage at a time.
static func whole() -> WaveSet:
	var siege := WaveSet.new()
	var all: Array[WaveData] = []
	for stage: int in STAGES.size():
		var part: WaveSet = waves(stage)
		if stage == 0:
			siege.opening_delay = part.opening_delay
			siege.health_growth = part.health_growth
			siege.speed_growth = part.speed_growth
		all.append_array(part.waves)
	siege.waves = all
	return siege


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
