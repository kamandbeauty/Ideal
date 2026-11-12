class_name FrameMonitor
extends RefCounted
## Watches frame times and says when the 3D render resolution should move. It
## only reacts to sustained trouble: one slow frame (a shader compile, a save)
## never changes quality. The thresholds come from GovernorSettings.

var rules := GovernorSettings.new()
## The rate actually aimed for: the configured one, or the display's if that is lower.
var target_fps: float = 60.0
var slow_time: float = 0.0
var fast_time: float = 0.0
var cooldown: float = 0.0
## Frame time smoothed over about a second; 0 until the first frame has been seen.
var average_ms: float = 0.0


## A display that refreshes slower than the configured target sets the target.
static func effective_target(wanted: float, refresh: float) -> float:
	return minf(wanted, refresh) if refresh >= 20.0 else wanted


func budget_ms() -> float:
	return 1000.0 / maxf(target_fps, 1.0)


func is_slow(frame_ms: float) -> bool:
	return frame_ms > budget_ms() * rules.slow_ratio


func is_fast(frame_ms: float) -> bool:
	return frame_ms <= budget_ms() * rules.fast_ratio


## The frame rate below which a frame counts as slow (49 with the shipped numbers).
func slow_below_fps() -> float:
	return target_fps / rules.slow_ratio


func reset() -> void:
	slow_time = 0.0
	fast_time = 0.0
	cooldown = 0.0
	average_ms = 0.0


## Returns -1 to lower the render resolution, +1 to raise it, 0 to hold.
func tick(frame_ms: float, delta: float) -> int:
	average_ms = frame_ms if average_ms <= 0.0 else lerpf(average_ms, frame_ms, 1.0 - exp(-delta))
	if cooldown > 0.0:
		cooldown -= delta
		return 0
	if is_slow(frame_ms):
		slow_time += delta
		fast_time = 0.0
	elif is_fast(frame_ms):
		fast_time += delta
		slow_time = maxf(0.0, slow_time - delta * 0.5)
	else:
		slow_time = maxf(0.0, slow_time - delta * 0.5)
		fast_time = 0.0
	if slow_time >= rules.slow_window:
		slow_time = 0.0
		cooldown = rules.cooldown_after_lowering
		return -1
	if fast_time >= rules.fast_window:
		fast_time = 0.0
		cooldown = rules.cooldown_after_raising
		return 1
	return 0
