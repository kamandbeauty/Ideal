extends Node
## Autoload Graphics: quality tiers for phones, plus a governor for players
## who leave quality on "auto". It reacts only to sustained frame-time trouble,
## tries the cheapest thing first, and checks that what it did was worth it:
##   1. the render resolution goes down a step at a time, and back up when
##      frames are fast again; a step up that is regretted at once sets a
##      ceiling, so the resolution cannot swing back and forth;
##   2. if the resolution has gone all the way down and frames are no shorter,
##      the pixels were never the problem: it is given back and left alone;
##   3. still slow with nothing left to try, one tier is given up; if that buys
##      nothing either, the tier is taken back and tiers are left alone.
## Its numbers are in resources/graphics/governor.tres (GovernorSettings).

signal quality_changed(tier: String)

const TIERS: Array[String] = ["low", "medium", "high"]
## What each tier pays for. "lights" are the short-lived lights of muzzle
## flashes and blasts, "detail" the particle dressing a fight can do without
## (stone chips, gun smoke), "ash" the flecks drifting over the street.
const PROFILES: Dictionary = {
	"low": {"scale": 0.7, "shadows": false, "shadow_distance": 60.0, "msaa": 0, "glow": false, "normal_maps": false, "particles": 0.5,
		"corpses": 10, "fires": 2, "ash": false, "lights": false, "detail": false},
	"medium": {"scale": 0.85, "shadows": true, "shadow_distance": 85.0, "msaa": 0, "glow": false, "normal_maps": true, "particles": 0.75,
		"corpses": 18, "fires": 4, "ash": true, "lights": true, "detail": true},
	"high": {"scale": 1.0, "shadows": true, "shadow_distance": 130.0, "msaa": 1, "glow": true, "normal_maps": true, "particles": 1.0,
		"corpses": 28, "fires": 8, "ash": true, "lights": true, "detail": true},
}

const RULES_PATH: String = "res://resources/graphics/governor.tres"

var tier: String = "medium"
## Switched off by the screenshot run, so that every picture shows the same tier at the same resolution.
var governor: bool = true
var rules: GovernorSettings
## The tier "auto" has settled on in this session; empty until the governor has had to give one up.
var auto_tier: String = ""
## The quality setting the current tier was applied for.
var applied_preference: String = ""
var applied: bool = false
var render_scale: float = 1.0
var monitor := FrameMonitor.new()
var fps: float = 60.0
var last_usec: int = 0
var warmup: float = 0.0
var compatibility: bool = false
## Seconds of slow frames with the resolution unable to help.
var floor_time: float = 0.0
## The highest resolution worth trying on this tier; lowered by a step up that was regretted.
var scale_ceiling: float = 1.0
## Lowering the resolution was tried and bought nothing: it is left at the tier's own.
var scale_useless: bool = false
## Smoothed frame time when the resolution last started down from the top; negative when not probing.
var probe_ms: float = -1.0
var since_raise: float = 1000.0
## The tier that was given up most recently, the frame time it had, and how long until that is judged.
var tier_before_drop: String = ""
var tier_probe_ms: float = -1.0
var tier_judge_left: float = 0.0
## Tiers are settled for this session: nothing lower to try, or a drop was taken back.
var tier_locked: bool = false
## How often the governor has acted since the quality setting last changed; tests read these.
var scale_changes: int = 0
var tier_changes: int = 0
## MSAA has been bound once. Recreating that buffer on the mobile renderer
## tears or blacks the picture; scale uses bilinear 3D scaling and may move.
var msaa_committed: bool = false
## True after the first bind of the 3D buffer (MSAA + initial scale).
var viewport_committed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	compatibility = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	rules = load(RULES_PATH) as GovernorSettings
	if rules == null:
		rules = GovernorSettings.new()
	monitor.rules = rules
	monitor.target_fps = FrameMonitor.effective_target(rules.target_fps, DisplayServer.screen_get_refresh_rate())
	Profile.changed.connect(apply_preference)
	apply_preference()
	last_usec = Time.get_ticks_usec()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# The frame that spans the time away says nothing about the phone.
		last_usec = Time.get_ticks_usec()
		warmup = maxf(warmup, 1.0)
		monitor.reset()


func resolve_tier(preference: String) -> String:
	if TIERS.has(preference):
		return preference
	if auto_tier != "":
		return auto_tier
	return "medium" if OS.has_feature("mobile") else "high"


## Called whenever a setting changes. Only a change of the quality setting does anything: moving a
## volume slider must not rebuild every particle emitter or throw away what the governor has learnt.
func apply_preference() -> void:
	var preference: String = Profile.data.settings.quality
	var wanted: String = resolve_tier(preference)
	if applied and preference == applied_preference and wanted == tier:
		return
	applied = true
	applied_preference = preference
	forget()
	warmup = rules.warmup if rules else 4.0
	apply_tier(wanted)


## Drops everything the governor has concluded about the current tier (not the tier "auto" has settled on).
func forget() -> void:
	floor_time = 0.0
	scale_ceiling = 1.0
	scale_useless = false
	probe_ms = -1.0
	since_raise = 1000.0
	tier_before_drop = ""
	tier_probe_ms = -1.0
	tier_judge_left = 0.0
	tier_locked = false
	scale_changes = 0
	tier_changes = 0
	monitor.reset()


func profile() -> Dictionary:
	return PROFILES[tier]


func apply_tier(value: String) -> void:
	if not PROFILES.has(value):
		return
	tier = value
	var settings: Dictionary = profile()
	render_scale = settings.scale
	_apply_quality(settings)


## The 3D buffer's current scale, read from the viewport itself.
func buffer_scale() -> float:
	var viewport: Viewport = _root_viewport()
	return viewport.scaling_3d_scale if viewport else render_scale


func _root_viewport() -> Viewport:
	var window: Window = get_window()
	return window.get_viewport() if window else get_viewport()


func _apply_quality(settings: Dictionary) -> void:
	_sync_viewport(settings)
	MaterialLibrary.set_normal_maps(settings.normal_maps)
	get_tree().call_group("quality_listener", "apply_quality", tier, settings)
	quality_changed.emit(tier)


## Bilinear 3D scale may move at runtime (that is the governor's job). MSAA is
## bound once: recreating it on the mobile renderer tears the picture.
func _sync_viewport(settings: Dictionary) -> void:
	var viewport: Viewport = _root_viewport()
	if viewport == null:
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if not is_equal_approx(viewport.scaling_3d_scale, render_scale):
		viewport.scaling_3d_scale = render_scale
	if not msaa_committed:
		viewport.msaa_3d = Viewport.MSAA_DISABLED if compatibility else (settings.msaa as Viewport.MSAA)
		msaa_committed = true
	viewport_committed = true


func _write_scale() -> void:
	var viewport: Viewport = _root_viewport()
	if viewport == null:
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if not is_equal_approx(viewport.scaling_3d_scale, render_scale):
		viewport.scaling_3d_scale = render_scale


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - last_usec) / 1000.0
	last_usec = now
	fps = lerpf(fps, 1000.0 / clampf(frame_ms, 0.1, 500.0), 0.05)
	if warmup > 0.0:
		warmup -= delta
		return
	if governing():
		observe(frame_ms, delta)


## The governor only works for a player who left quality on "auto", and never judges a paused game.
func governing() -> bool:
	return governor and rules.enabled and not get_tree().paused and Profile.data.settings.quality == "auto"


## Feeds one frame to the governor. Only called with quality on "auto".
func observe(frame_ms: float, delta: float) -> void:
	since_raise += delta
	var base: float = profile().scale
	var lowest: float = minf(rules.scale_floor, base)
	var top: float = minf(base, scale_ceiling)
	# The render resolution moves first: it costs nothing to change. Switching tiers toggles
	# shadows and recompiles shaders, a hitch worth paying only once everything cheaper has failed.
	var adjustment: int = monitor.tick(frame_ms, delta)
	if scale_useless or tier_judge_left > 0.0:
		adjustment = 0
	if adjustment < 0 and render_scale > lowest + 0.001:
		if render_scale >= top - 0.001:
			probe_ms = monitor.average_ms
		if since_raise <= rules.regret_window:
			# The step up just taken was one too many: where it came from is as high as this phone goes.
			scale_ceiling = render_scale - rules.scale_step
		_set_scale(maxf(lowest, render_scale - rules.scale_step))
	elif adjustment > 0 and render_scale < top - 0.001:
		_set_scale(minf(top, render_scale + rules.scale_step))
		since_raise = 0.0
	var at_floor: bool = render_scale <= lowest + 0.001
	if (scale_useless or at_floor) and monitor.is_slow(frame_ms):
		floor_time += delta
	else:
		floor_time = maxf(0.0, floor_time - delta * 0.5)
	if at_floor and not scale_useless and probe_ms > 0.0 and floor_time >= rules.slow_window:
		if monitor.average_ms > probe_ms * (1.0 - rules.min_gain):
			# All the way down and the frames are no shorter: the pixels were never the problem.
			scale_useless = true
			_set_scale(base)
		probe_ms = -1.0
	if tier_judge_left > 0.0:
		tier_judge_left -= delta
		if tier_judge_left <= 0.0:
			_judge_drop()
	elif not tier_locked and floor_time >= rules.floor_patience:
		floor_time = 0.0
		_give_up_tier()


func _set_scale(value: float) -> void:
	if is_equal_approx(value, render_scale):
		return
	render_scale = value
	scale_changes += 1
	_write_scale()


func _give_up_tier() -> void:
	var index: int = TIERS.find(tier)
	if index <= maxi(TIERS.find(rules.lowest_tier), 0):
		# Nothing lower to try; the resolution goes on following the frames.
		tier_locked = true
		return
	tier_probe_ms = monitor.average_ms
	tier_before_drop = tier
	auto_tier = TIERS[index - 1]
	_change_tier(auto_tier)
	tier_judge_left = rules.tier_judge_window


## Did giving up a tier buy anything? If not, the phone is slow at any quality: take the better picture back and stop.
func _judge_drop() -> void:
	if tier_before_drop != "" and monitor.average_ms > tier_probe_ms * (1.0 - rules.min_gain):
		auto_tier = tier_before_drop
		_change_tier(auto_tier)
		tier_locked = true
	tier_before_drop = ""
	tier_probe_ms = -1.0
	# The tier that is kept gets a full measure of patience of its own.
	floor_time = 0.0


## Switches tier and keeps the resolution where it was, so that the frames before and after can be compared.
func _change_tier(value: String) -> void:
	if not PROFILES.has(value):
		return
	var held: float = render_scale
	tier = value
	var settings: Dictionary = profile()
	var base: float = settings.scale
	if not scale_useless:
		render_scale = clampf(held, minf(rules.scale_floor, base), base)
	else:
		render_scale = base
	_apply_quality(settings)
	tier_changes += 1
	monitor.reset()
	floor_time = 0.0
	scale_ceiling = 1.0
	probe_ms = -1.0
	since_raise = 1000.0
	# The switch itself costs a few slow frames; they say nothing about the new tier.
	warmup = rules.warmup


func snapshot() -> Dictionary:
	return {
		"fps": snappedf(fps, 0.1),
		"tier": tier,
		"scale": snappedf(render_scale, 0.01),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_memory_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"video_memory_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_memory_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"renderer": "Compatibility" if compatibility else "Mobile",
	}
