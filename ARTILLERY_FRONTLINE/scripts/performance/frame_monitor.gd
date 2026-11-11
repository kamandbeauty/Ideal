class_name FrameMonitor
extends RefCounted
## Decides when the 3D render scale should move. It only reacts to sustained
## trouble: one slow frame (a shader compile, a save) never changes quality.

var target_fps: float = 60.0
var window: float = 2.0
var slow_time: float = 0.0
var fast_time: float = 0.0
var cooldown: float = 0.0


## Returns -1 to lower the render scale, +1 to raise it, 0 to hold.
func tick(frame_ms: float, delta: float) -> int:
	if cooldown > 0.0:
		cooldown -= delta
		return 0
	var budget: float = 1000.0 / target_fps
	if frame_ms > budget * 1.22:
		slow_time += delta
		fast_time = 0.0
	elif frame_ms < budget * 1.05:
		fast_time += delta
		slow_time = maxf(0.0, slow_time - delta * 0.5)
	else:
		slow_time = maxf(0.0, slow_time - delta * 0.5)
		fast_time = 0.0
	if slow_time >= window:
		slow_time = 0.0
		cooldown = 1.5
		return -1
	if fast_time >= window * 4.0:
		fast_time = 0.0
		cooldown = 3.0
		return 1
	return 0
