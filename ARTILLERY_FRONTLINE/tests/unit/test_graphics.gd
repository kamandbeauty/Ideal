extends RefCounted
func run(t: TestContext) -> void:
	var low: Dictionary = Graphics.PROFILES.low
	var medium: Dictionary = Graphics.PROFILES.medium
	var high: Dictionary = Graphics.PROFILES.high
	t.check(low.scale < medium.scale and medium.scale < high.scale, "Resolution tiers ordered")
	t.check(low.effect_slots < medium.effect_slots and medium.effect_slots < high.effect_slots, "Bounded effect pools ordered")
	t.check(low.texture_size < high.texture_size, "Texture quality tiers differ")
	var monitor := SustainedFrameMonitor.new()
	t.equal(monitor.tick(500.0, 0.1), 0, "One stall does not reduce quality")
	var adjustment: int = 0
	for frame in range(600):
		adjustment += monitor.tick(25.0, 1.0 / 60.0)
	t.equal(adjustment, -1, "Sustained 40 FPS reduces 60 FPS tier")
	for frame in range(1200):
		monitor.tick(8.0, 1.0 / 60.0)
	var recovered: int = 0
	for frame in range(1200):
		recovered += monitor.tick(8.0, 1.0 / 60.0)
	t.equal(recovered, 1, "Sustained headroom restores quality with hysteresis")
	monitor.target_fps = 30
	monitor.cooldown = 0.0
	monitor.fast_windows = 0
	monitor.slow_windows = 0
	var stable30: int = 0
	for frame in range(900):
		stable30 += monitor.tick(30.0, 1.0 / 30.0)
	t.equal(stable30, 0, "Healthy 30 FPS target does not downgrade")
