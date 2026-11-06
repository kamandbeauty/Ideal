extends RefCounted
func run(t: TestContext) -> void:
	var low: Dictionary = Graphics.PROFILES.low
	var medium: Dictionary = Graphics.PROFILES.medium
	var high: Dictionary = Graphics.PROFILES.high
	var ultra: Dictionary = Graphics.PROFILES.ultra
	t.check(low.scale < medium.scale and medium.scale < high.scale, "Resolution tiers ordered")
	t.check(low.effect_slots < medium.effect_slots and medium.effect_slots < high.effect_slots, "Bounded effect pools ordered")
	t.check(low.texture_size < high.texture_size and high.texture_size <= ultra.texture_size, "Texture quality tiers differ")
	t.check(high.scale <= ultra.scale and high.shadow_distance < ultra.shadow_distance, "Ultra extends high without reducing resolution")
	t.check(Graphics.TIERS.find("ultra") > Graphics.TIERS.find("high") and Graphics.AUTO_MAX_INDEX == Graphics.TIERS.find("high"), "Adaptive quality is capped below manual ultra")
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
