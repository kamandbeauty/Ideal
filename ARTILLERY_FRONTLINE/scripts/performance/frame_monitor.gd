class_name SustainedFrameMonitor
extends RefCounted
## Windowed hysteresis, not reactions to isolated stalls.
var target_fps: int = 60
var sample_seconds: float = 0.0
var sample_total: float = 0.0
var sample_count: int = 0
var slow_windows: int = 0
var fast_windows: int = 0
var cooldown: float = 0.0
var average_ms: float = 0.0

func tick(frame_ms: float, seconds: float) -> int:
	cooldown = maxf(0.0, cooldown - seconds)
	if frame_ms <= 0.0 or frame_ms > 1000.0:
		return 0
	sample_seconds += seconds
	sample_total += frame_ms
	sample_count += 1
	if sample_seconds < 4.0:
		return 0
	average_ms = sample_total / maxf(1.0, float(sample_count))
	sample_seconds = 0.0
	sample_total = 0.0
	sample_count = 0
	var budget: float = 1000.0 / float(target_fps)
	slow_windows = slow_windows + 1 if average_ms > budget * 1.22 else 0
	fast_windows = fast_windows + 1 if average_ms < budget * 0.72 else 0
	if cooldown > 0.0:
		return 0
	if slow_windows >= 2:
		slow_windows = 0
		fast_windows = 0
		cooldown = 8.0
		return -1
	if fast_windows >= 4:
		fast_windows = 0
		cooldown = 12.0
		return 1
	return 0
