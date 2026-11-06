extends Node
## Autoload Graphics. Mobile-first quality tiers and sustained adaptation.
signal quality_changed(tier: String)
const TIERS: Array[String] = ["low", "medium", "high", "ultra"]
const AUTO_MAX_INDEX: int = 2
const PROFILES: Dictionary = {
	"low": {"scale": 0.62, "shadows": false, "shadow_distance": 55.0, "particles": 0.4, "effect_slots": 4, "detail": 0.35, "visibility": 650.0, "msaa": 0, "texture_size": 128, "mip_bias": 0.7, "ssao": false, "glow": false, "dof": false},
	"medium": {"scale": 0.82, "shadows": true, "shadow_distance": 90.0, "particles": 0.7, "effect_slots": 7, "detail": 0.65, "visibility": 950.0, "msaa": 0, "texture_size": 256, "mip_bias": 0.25, "ssao": false, "glow": false, "dof": false},
	"high": {"scale": 1.0, "shadows": true, "shadow_distance": 180.0, "particles": 1.0, "effect_slots": 10, "detail": 1.0, "visibility": 1400.0, "msaa": 2, "texture_size": 512, "mip_bias": 0.0, "ssao": true, "glow": true, "dof": false},
	"ultra": {"scale": 1.0, "shadows": true, "shadow_distance": 240.0, "particles": 1.0, "effect_slots": 10, "detail": 1.0, "visibility": 1600.0, "msaa": 2, "texture_size": 1024, "mip_bias": -0.2, "ssao": true, "glow": true, "dof": true}
}
var tier: String = "medium"
var monitor := SustainedFrameMonitor.new()
var last_usec: int = 0
var warmup: float = 0.0
var fps: float = 60.0
var draw_calls: int = 0
var primitives: int = 0
var compatibility: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	compatibility = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if OS.has_feature("android"):
		tier = "medium"
	else:
		tier = "high"
	apply_preference()
	Profile.changed.connect(apply_preference)
	last_usec = Time.get_ticks_usec()

func apply_preference() -> void:
	var preference: String = Profile.data.settings.quality
	monitor = SustainedFrameMonitor.new()
	monitor.target_fps = int(Profile.data.settings.fps_target)
	Engine.max_fps = monitor.target_fps
	warmup = 4.0
	if preference != "auto":
		tier = preference
	elif not OS.has_feature("android"):
		tier = "high"
	apply_tier(tier)

func profile() -> Dictionary:
	return PROFILES[tier]

func apply_tier(value: String) -> void:
	if not PROFILES.has(value):
		return
	tier = value
	var settings: Dictionary = profile()
	MaterialLibrary.apply_quality(settings)
	var viewport: Viewport = get_viewport()
	if viewport:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = settings.scale
		viewport.msaa_3d = Viewport.MSAA_DISABLED if compatibility else int(settings.msaa)
		viewport.positional_shadow_atlas_size = 0 if tier == "low" else (1024 if tier == "medium" else 2048)
		viewport.texture_mipmap_bias = float(settings.mip_bias)
	get_tree().call_group("quality_listener", "apply_quality", tier, settings)
	quality_changed.emit(tier)

func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - last_usec) / 1000.0
	last_usec = now
	fps = lerpf(fps, 1000.0 / maxf(frame_ms, 0.1), 0.04)
	draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if warmup > 0.0:
		warmup -= delta
		return
	if get_tree().paused or Profile.data.settings.quality != "auto":
		return
	var adjustment: int = monitor.tick(frame_ms, delta)
	if adjustment != 0:
		var index: int = clampi(TIERS.find(tier) + adjustment, 0, AUTO_MAX_INDEX)
		if TIERS[index] != tier:
			apply_tier(TIERS[index])

func snapshot() -> Dictionary:
	return {"fps": snappedf(fps, 0.1), "frame_ms": snappedf(1000.0 / maxf(fps, 0.1), 0.01), "draw_calls": draw_calls, "primitives": primitives, "tier": tier, "scale": profile().scale, "objects": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "renderer": "Compatibility" if compatibility else "Mobile"}
