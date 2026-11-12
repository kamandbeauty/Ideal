extends RefCounted

# Test-only weak references observe AudioServer playbacks without owning them.
static var playbacks: Array[WeakRef] = []

static func record(playback: AudioStreamPlayback) -> void:
	if OS.has_environment("CI_SOUND_DIAGNOSTICS"):
		prune()
		playbacks.append(weakref(playback))

static func prune() -> void:
	playbacks = playbacks.filter(func(ref: WeakRef): return ref.get_ref() != null)

static func drain(tree: SceneTree) -> bool:
	# Stopping a player schedules a fade-out on the mixer thread; Godot then
	# releases the server's reference on a subsequent main-thread update.
	# Observe references, not elapsed time, with a deadline only for failure.
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		prune()
		if playbacks.is_empty():
			print("Audio playback references drained")
			return true
		OS.delay_msec(2)
		await tree.process_frame
	prune()
	printerr("FAIL: audio playbacks still retained after deadline: ", playbacks.size())
	return false
