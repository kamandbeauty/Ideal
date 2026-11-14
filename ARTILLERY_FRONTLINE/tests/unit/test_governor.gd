extends RefCounted
## The quality governor must move the real 3D buffer, not only a variable.
## MSAA stays bound after the first commit so the mobile renderer does not tear.


func run(t: TestContext) -> void:
	var shipped: GovernorSettings = Graphics.rules
	var tier_before: String = Graphics.tier
	var auto_before: String = Graphics.auto_tier
	var scale_before: float = Graphics.render_scale
	var viewport: Viewport = Graphics.get_viewport()
	t.check(viewport != null, "the autoload has a root viewport")
	if viewport == null:
		return
	t.equal(viewport.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR, "3D scaling is bilinear (the mobile-safe path)")

	# Manual quality: each tier writes its own scale onto the viewport.
	var msaa: int = viewport.msaa_3d
	for id: String in Graphics.TIERS:
		Graphics.apply_tier(id)
		var wanted: float = float(Graphics.PROFILES[id].scale)
		t.near(Graphics.render_scale, wanted, 0.0001, "%s stores its scale" % id)
		t.near(viewport.scaling_3d_scale, wanted, 0.0001, "%s actually sizes the 3D buffer to %.2f" % [id, wanted])
		t.near(Graphics.buffer_scale(), Graphics.render_scale, 0.0001, "%s: buffer_scale agrees with the viewport" % id)
	t.equal(viewport.msaa_3d, msaa, "switching tiers does not recreate MSAA")

	# Auto governor: a fill-rate-bound phone lowers the real buffer.
	var rules := GovernorSettings.new()
	Graphics.rules = rules
	Graphics.monitor.rules = rules
	Graphics.monitor.target_fps = 60.0
	Graphics.auto_tier = ""
	Graphics.forget()
	Graphics.apply_tier("medium")
	t.near(viewport.scaling_3d_scale, float(Graphics.PROFILES["medium"].scale), 0.0001, "medium starts at its own buffer")
	var fill := func(_tier: String, scale: float) -> float: return 8.0 + 22.0 * scale * scale
	var left: float = 2.6
	while left > 0.0:
		var frame_ms: float = fill.call(Graphics.tier, Graphics.render_scale)
		var delta: float = minf(frame_ms / 1000.0, 0.1)
		Graphics.observe(frame_ms, delta)
		left -= delta
	t.check(Graphics.render_scale < float(Graphics.PROFILES["medium"].scale) - 0.001, "the governor lowered render_scale")
	t.near(viewport.scaling_3d_scale, Graphics.render_scale, 0.0001, "and the viewport scale is that value, not the old one")
	t.equal(viewport.msaa_3d, msaa, "the drop does not touch MSAA")
	var lowered: float = Graphics.render_scale
	var recover: float = 12.0
	while recover > 0.0:
		Graphics.observe(12.0, 0.1)
		recover -= 0.1
	t.check(Graphics.render_scale > lowered + 0.001, "fast frames raise the buffer again (%.2f after %.2f)" % [Graphics.render_scale, lowered])
	t.near(viewport.scaling_3d_scale, Graphics.render_scale, 0.0001, "the 3D buffer follows the raise, not only the drop")
	t.equal(viewport.msaa_3d, msaa, "raising scale still leaves MSAA as first committed")

	# A player who picks a tier gets that tier's buffer at once, governor or not.
	Profile.persist = false
	Profile.set_setting("quality", "low")
	t.near(viewport.scaling_3d_scale, float(Graphics.PROFILES["low"].scale), 0.0001, "choosing low writes the low buffer")
	Profile.set_setting("quality", "high")
	t.near(viewport.scaling_3d_scale, float(Graphics.PROFILES["high"].scale), 0.0001, "choosing high writes the high buffer")
	t.check(not Graphics.governing(), "a chosen tier is not governed")
	Profile.set_setting("quality", "auto")

	Graphics.rules = shipped
	Graphics.monitor.rules = shipped
	Graphics.auto_tier = auto_before
	Profile.reset()
	Graphics.apply_preference()
	Graphics.forget()
	if Graphics.tier != tier_before:
		Graphics.apply_tier(tier_before)
	elif not is_equal_approx(Graphics.render_scale, scale_before):
		Graphics.apply_tier(tier_before)
