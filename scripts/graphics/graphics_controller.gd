class_name GraphicsController
extends Node

signal quality_changed(profile_name: String)

var policy := QualityPolicy.new()
var sun: DirectionalLight3D
var effect_pool: Node
var detail_group: Node3D


func configure(mode: String, fps: int) -> void:
	policy.configure(mode, fps)
	Engine.max_fps = policy.target_fps
	_apply()


func _process(delta: float) -> void:
	if policy.sample_frame(delta):
		_apply()


func _apply() -> void:
	var profile := policy.profile()
	if get_viewport() != null:
		get_viewport().scaling_3d_scale = profile.scale
		get_viewport().mesh_lod_threshold = profile.lod
	if is_instance_valid(sun):
		sun.shadow_enabled = profile.shadows
		sun.directional_shadow_max_distance = profile.shadow_distance
	if is_instance_valid(detail_group):
		detail_group.visible = profile.detail
	if is_instance_valid(effect_pool):
		effect_pool.set_particle_scale(profile.particles)
	quality_changed.emit(profile.name)
