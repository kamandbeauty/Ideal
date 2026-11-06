class_name QualityPolicy
extends RefCounted
## Sustained windows and hysteresis prevent oscillation on isolated frame spikes.

const PROFILES: Array[Dictionary] = [
	{
		"name": "LOW",
		"scale": 0.70,
		"shadows": false,
		"shadow_distance": 35.0,
		"particles": 0.45,
		"detail": false,
		"lod": 2.0
	},
	{
		"name": "MEDIUM",
		"scale": 0.85,
		"shadows": true,
		"shadow_distance": 75.0,
		"particles": 0.70,
		"detail": true,
		"lod": 1.4
	},
	{
		"name": "HIGH",
		"scale": 1.0,
		"shadows": true,
		"shadow_distance": 120.0,
		"particles": 1.0,
		"detail": true,
		"lod": 1.0
	},
]
const WINDOW_SECONDS: float = 5.0
const SLOW_WINDOWS: int = 2
const FAST_WINDOWS: int = 4

var mode: String = "AUTO"
var level: int = 1
var target_fps: int = 60
var _window_time: float = 0.0
var _frames: int = 0
var _slow_windows: int = 0
var _fast_windows: int = 0


func configure(new_mode: String, fps: int) -> void:
	mode = new_mode if new_mode in ["AUTO", "LOW", "MEDIUM", "HIGH"] else "AUTO"
	target_fps = 30 if fps == 30 else 60
	level = {"LOW": 0, "MEDIUM": 1, "HIGH": 2, "AUTO": 1}[mode]
	_window_time = 0.0
	_frames = 0
	_slow_windows = 0
	_fast_windows = 0


func profile() -> Dictionary:
	return PROFILES[level]


func sample_frame(delta: float) -> bool:
	if mode != "AUTO" or delta <= 0.0:
		return false
	_window_time += delta
	_frames += 1
	if _window_time < WINDOW_SECONDS:
		return false
	var fps := float(_frames) / _window_time
	_window_time = 0.0
	_frames = 0
	if fps < float(target_fps) * 0.88:
		_slow_windows += 1
		_fast_windows = 0
	elif fps > float(target_fps) * 0.98:
		_fast_windows += 1
		_slow_windows = 0
	else:
		_slow_windows = 0
		_fast_windows = 0
	var old_level := level
	if _slow_windows >= SLOW_WINDOWS:
		level = maxi(level - 1, 0)
		_slow_windows = 0
	elif _fast_windows >= FAST_WINDOWS:
		level = mini(level + 1, 2)
		_fast_windows = 0
	return old_level != level
