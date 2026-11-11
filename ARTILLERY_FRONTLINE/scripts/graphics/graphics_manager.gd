extends Node
## Autoload Graphics: quality tiers for phones, plus a governor that only
## reacts to sustained frame-time trouble. With quality on "auto" it first
## lowers the render resolution; if the frames are still slow with the
## resolution at its floor, it gives up one tier, once, and stays there.

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

## The lowest render scale the governor goes to, and how many seconds of slow frames it then
## waits before giving up a tier: lowering the resolution does not help a phone held back by its processor.
const SCALE_FLOOR: float = 0.55
const FLOOR_PATIENCE: float = 8.0

var tier: String = "medium"
## The tier "auto" has settled on in this session; empty until the governor has had to give one up. It only moves down.
var auto_tier: String = ""
var floor_time: float = 0.0
## The quality setting the current tier was applied for.
var applied_preference: String = ""
var applied: bool = false
var render_scale: float = 1.0
var monitor := FrameMonitor.new()
var fps: float = 60.0
var last_usec: int = 0
var warmup: float = 0.0
var compatibility: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	compatibility = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	Profile.changed.connect(apply_preference)
	apply_preference()
	last_usec = Time.get_ticks_usec()


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
	warmup = 4.0
	floor_time = 0.0
	monitor.reset()
	apply_tier(wanted)


func profile() -> Dictionary:
	return PROFILES[tier]


func apply_tier(value: String) -> void:
	if not PROFILES.has(value):
		return
	tier = value
	var settings: Dictionary = profile()
	render_scale = settings.scale
	var viewport: Viewport = get_viewport()
	if viewport:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = render_scale
		viewport.msaa_3d = Viewport.MSAA_DISABLED if compatibility else (settings.msaa as Viewport.MSAA)
	MaterialLibrary.set_normal_maps(settings.normal_maps)
	get_tree().call_group("quality_listener", "apply_quality", tier, settings)
	quality_changed.emit(tier)


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - last_usec) / 1000.0
	last_usec = now
	fps = lerpf(fps, 1000.0 / maxf(frame_ms, 0.1), 0.05)
	if warmup > 0.0:
		warmup -= delta
		return
	if get_tree().paused or Profile.data.settings.quality != "auto":
		return
	observe(frame_ms, delta)


## Feeds one frame to the governor. Only called with quality on "auto".
func observe(frame_ms: float, delta: float) -> void:
	# The render resolution moves first: it costs nothing to change. Switching tiers toggles
	# shadows and recompiles shaders, a hitch worth paying only once everything cheaper has failed.
	var adjustment: int = monitor.tick(frame_ms, delta)
	if adjustment != 0:
		var base: float = profile().scale
		render_scale = clampf(render_scale + float(adjustment) * 0.06, minf(SCALE_FLOOR, base), base)
		var viewport: Viewport = get_viewport()
		if viewport:
			viewport.scaling_3d_scale = render_scale
	if render_scale <= SCALE_FLOOR + 0.001 and monitor.is_slow(frame_ms):
		floor_time += delta
	else:
		floor_time = maxf(0.0, floor_time - delta * 0.5)
	if floor_time >= FLOOR_PATIENCE:
		floor_time = 0.0
		_give_up_tier()


func _give_up_tier() -> void:
	var index: int = TIERS.find(tier)
	if index <= 0:
		return
	auto_tier = TIERS[index - 1]
	apply_tier(auto_tier)
	monitor.reset()
	# The switch itself costs a few slow frames; they say nothing about the new tier.
	warmup = 4.0


func snapshot() -> Dictionary:
	return {
		"fps": snappedf(fps, 0.1),
		"tier": tier,
		"scale": snappedf(render_scale, 0.01),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"renderer": "Compatibility" if compatibility else "Mobile",
	}
