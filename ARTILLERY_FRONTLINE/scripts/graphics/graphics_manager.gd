extends Node
## Autoload Graphics: quality tiers for phones, plus a render-scale governor
## that only reacts to sustained frame-time trouble.

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

var tier: String = "medium"
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
	return "medium" if OS.has_feature("mobile") else "high"


func apply_preference() -> void:
	var wanted: String = resolve_tier(Profile.data.settings.quality)
	warmup = 4.0
	if wanted != tier or render_scale <= 0.0:
		apply_tier(wanted)
	else:
		apply_tier(tier)


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
	# Only the render resolution moves mid-fight: switching tiers would toggle
	# shadows and recompile shaders, which costs more frames than it saves.
	var adjustment: int = monitor.tick(frame_ms, delta)
	if adjustment != 0:
		var base: float = profile().scale
		render_scale = clampf(render_scale + float(adjustment) * 0.06, 0.55, base)
		var viewport: Viewport = get_viewport()
		if viewport:
			viewport.scaling_3d_scale = render_scale


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
