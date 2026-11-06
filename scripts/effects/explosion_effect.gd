class_name ExplosionEffect
extends Node3D
## Four bounded, one-shot GPU particle layers plus a flash and expanding shockwave.

var active: bool = false
var age: float = 0.0
var particle_scale: float = 1.0
var _layers: Array[GPUParticles3D] = []
var _base_amounts: Array[int] = [24, 28, 18, 16]
var _fireball: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	var fire := _particle_material(Color(1.0, 0.43, 0.08, 1.0), true)
	var dust := _particle_material(Color(0.67, 0.52, 0.34, 0.75), false)
	var smoke := _particle_material(Color(0.20, 0.20, 0.18, 0.82), false)
	var debris := _particle_material(Color(0.34, 0.29, 0.21, 1.0), false)
	_layers.append(_make_layer(fire, 0.65, 11.0, Vector3(0, -5, 0), 1.0, 2.2, 85.0))
	_layers.append(_make_layer(dust, 1.55, 8.0, Vector3(0, -2, 0), 1.2, 3.5, 80.0))
	_layers.append(_make_layer(smoke, 2.1, 5.0, Vector3(0, 1.0, 0), 1.3, 3.0, 48.0))
	_layers.append(_make_layer(debris, 1.2, 13.0, Vector3(0, -18, 0), 0.2, 0.5, 70.0))
	var flash_mat := _particle_material(Color("ffc058"), true)
	_fireball = ShapeFactory.sphere(self, Vector3.ONE, Vector3.ZERO, flash_mat, 12)
	_fireball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat := _particle_material(Color("e4c693"), true)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 20
	torus.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = ring_mat
	_ring.position.y = 0.2
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_light = OmniLight3D.new()
	_light.light_color = Color("ffab45")
	_light.omni_range = 20.0
	_light.light_energy = 0.0
	add_child(_light)
	visible = false
	set_process(false)


func play_at(point: Vector3) -> void:
	global_position = point
	age = 0.0
	active = true
	visible = true
	_fireball.visible = true
	_ring.visible = true
	_light.light_energy = 7.0
	for i in range(_layers.size()):
		_layers[i].amount = maxi(1, int(_base_amounts[i] * particle_scale))
		_layers[i].restart()
		_layers[i].emitting = true
	set_process(true)


func _process(delta: float) -> void:
	age += delta
	var flash_size := lerpf(0.7, 5.3, minf(age / 0.22, 1.0))
	_fireball.scale = Vector3.ONE * flash_size
	_fireball.visible = age < 0.22
	_ring.scale = Vector3.ONE * lerpf(0.8, 7.0, minf(age / 0.55, 1.0))
	_ring.visible = age < 0.55
	_light.light_energy = maxf(0.0, 7.0 * (1.0 - age / 0.35))
	if age >= 2.5:
		active = false
		visible = false
		set_process(false)


func _particle_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := ShapeFactory.material(color)
	material.vertex_color_use_as_albedo = true
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	return material


func _make_layer(
	surface: Material,
	lifetime: float,
	speed: float,
	gravity: Vector3,
	min_scale: float,
	max_scale: float,
	spread: float
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.98
	particles.lifetime = lifetime
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-25, -5, -25), Vector3(50, 40, 50))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = spread
	process.initial_velocity_min = speed * 0.35
	process.initial_velocity_max = speed
	process.gravity = gravity
	process.scale_min = min_scale
	process.scale_max = max_scale
	particles.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = surface
	particles.draw_pass_1 = mesh
	add_child(particles)
	return particles
