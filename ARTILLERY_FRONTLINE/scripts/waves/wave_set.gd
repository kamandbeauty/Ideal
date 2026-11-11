class_name WaveSet
extends Resource
## One stage of the siege: its waves in order, plus how the horde hardens from wave to wave.

@export var waves: Array[WaveData] = []
## Seconds of calm before the first wave.
@export_range(0.0, 60.0, 0.5) var opening_delay: float = 4.0
## Added to zombie health per wave already survived (0.08 = +8 %).
@export_range(0.0, 1.0, 0.01) var health_growth: float = 0.08
## Added to zombie speed per wave already survived.
@export_range(0.0, 0.5, 0.005) var speed_growth: float = 0.03
## Waves of the siege that came before this stage: the horde arrives already that much harder.
@export_range(0, 60) var waves_before: int = 0


func health_scale(wave_index: int) -> float:
	return 1.0 + health_growth * float(waves_before + wave_index)


func speed_scale(wave_index: int) -> float:
	return 1.0 + speed_growth * float(waves_before + wave_index)


func total_zombies() -> int:
	var sum: int = 0
	for wave: WaveData in waves:
		if wave != null:
			sum += wave.total()
	return sum
