class_name ExplosionEffect
extends Node3D
## Reusable layered GPU fire/smoke/dust, bounded manual debris, light and ring.
var fire: GPUParticles3D
var smoke: GPUParticles3D
var dust: GPUParticles3D
var debris: Array[MeshInstance3D] = []
var debris_velocity: Array[Vector3] = []
var shockwave: MeshInstance3D
var flash: OmniLight3D
var age: float = 100.0
var active: bool = false
var radius: float = 10.0
var ground_y: float = 0.0
var muzzle: bool = false
var particle_ratio: float = 1.0
var rng := RandomNumberGenerator.new()
const SMOKE_LIFE: float = 3.0
const DUST_LIFE: float = 2.0
const EFFECT_LIFE: float = 3.4
static var puff_texture: ImageTexture
static var fire_ramp: GradientTexture1D
static var smoke_ramp: GradientTexture1D
static var dust_ramp: GradientTexture1D

func _ready() -> void:
	_init_textures()
	fire = _particles("FlashFire", 48, 0.85, fire_ramp, true)
	_set_velocity(fire, 6.0, 17.0)
	(fire.process_material as ParticleProcessMaterial).gravity = Vector3(0, 3, 0)
	smoke = _particles("LayeredSmoke", 40, SMOKE_LIFE, smoke_ramp, false)
	_set_velocity(smoke, 1.0, 3.0)
	var smoke_process: ParticleProcessMaterial = smoke.process_material
	# Smoke is low and short-lived: it hugs the ground and thins out instead of
	# climbing into the sky as a hanging column.
	smoke_process.gravity = Vector3(0, 0.25, 0)
	smoke_process.damping_min = 1.0
	smoke_process.damping_max = 2.0
	dust = _particles("GroundDust", 30, DUST_LIFE, dust_ramp, false)
	_set_velocity(dust, 8.0, 19.0)
	var dust_process: ParticleProcessMaterial = dust.process_material
	dust_process.gravity = Vector3(0, -1.5, 0)
	dust_process.spread = 75.0
	for index in range(8):
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.25, 0.18, 0.4)
		piece.mesh = mesh
		piece.material_override = MeshFactory.material(Color(0.18, 0.16, 0.12))
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		debris.append(piece)
		debris_velocity.append(Vector3.ZERO)
	shockwave = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.91
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 6
	shockwave.mesh = ring
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(0.78, 0.66, 0.45, 0.35)
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shockwave.material_override = ring_material
	shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shockwave)
	flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.52, 0.16)
	flash.omni_range = 35.0
	flash.omni_attenuation = 1.6
	flash.shadow_enabled = false
	add_child(flash)
	visible = false
	set_process(false)

func _init_textures() -> void:
	if puff_texture:
		return
	var size: int = 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 9182
	noise.frequency = 0.045
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	for y in range(size):
		for x in range(size):
			var distance: float = Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var wisps: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var alpha: float = pow(maxf(0.0, 1.0 - distance), 1.25) * (0.55 + wisps * 0.65)
			image.set_pixel(x, y, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))
	puff_texture = ImageTexture.create_from_image(image)
	fire_ramp = _gradient([Color(1.0, 0.92, 0.53, 1), Color(1.0, 0.38, 0.055, 0.95), Color(0.3, 0.11, 0.035, 0)], [0.0, 0.35, 1.0])
	smoke_ramp = _gradient([Color(0.30, 0.28, 0.25, 0), Color(0.34, 0.32, 0.29, 0.52), Color(0.48, 0.46, 0.42, 0)], [0.0, 0.22, 1.0])
	dust_ramp = _gradient([Color(0.59, 0.48, 0.32, 0.55), Color(0.65, 0.55, 0.40, 0.32), Color(0.65, 0.56, 0.43, 0)], [0.0, 0.4, 1.0])

func _gradient(colors: Array[Color], offsets: Array[float]) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 64
	return texture

func _particles(name: String, amount: int, lifetime: float, ramp: GradientTexture1D, emissive: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.96
	particles.local_coords = false
	particles.fixed_fps = 30
	particles.emitting = false
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.gravity = Vector3.ZERO
	process.angular_velocity_min = -35.0
	process.angular_velocity_max = 35.0
	process.scale_min = 1.0
	process.scale_max = 2.0
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	particles.draw_pass_1 = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = false
	material.albedo_texture = puff_texture
	if not emissive:
		material.albedo_color = Color(0.42, 0.40, 0.37, 0.4) if name == "LayeredSmoke" else Color(0.62, 0.53, 0.38, 0.4)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if emissive:
		material.albedo_color = Color(1.0, 0.62, 0.25, 0.9)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.35, 0.04)
		material.emission_energy_multiplier = 2.0
	particles.material_override = material
	add_child(particles)
	return particles

func _set_velocity(particles: GPUParticles3D, minimum: float, maximum: float) -> void:
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	process.initial_velocity_min = minimum
	process.initial_velocity_max = maximum

func activate(point: Vector3, blast_radius: float, ground: float, quality_ratio: float, is_muzzle: bool = false) -> void:
	global_position = point
	radius = blast_radius
	ground_y = ground
	particle_ratio = quality_ratio
	muzzle = is_muzzle
	age = 0.0
	active = true
	visible = true
	set_process(true)
	rng.seed = int(absf(point.x * 731.0 + point.z * 193.0)) + 42
	var effect_scale: float = clampf(radius / 12.0, 0.18, 1.8)
	for particles in [fire, smoke, dust]:
		var base_amount: int = 48 if particles == fire else (40 if particles == smoke else 30)
		var wanted: int = maxi(4, int(base_amount * quality_ratio))
		# Changing GPU particle amount reallocates buffers; only do it when the
		# quality tier actually changes, never on every shot.
		if particles.amount != wanted:
			particles.amount = wanted
		var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
		process.scale_min = (1.4 if particles == fire else 2.5) * effect_scale
		process.scale_max = (3.8 if particles == fire else (4.0 if particles == smoke else 5.0)) * minf(effect_scale, 1.2)
		particles.restart()
		particles.emitting = true
	_set_velocity(fire, 6.0 * effect_scale, 17.0 * effect_scale)
	_set_velocity(smoke, 1.0 * effect_scale, 3.0 * effect_scale)
	_set_velocity(dust, 8.0 * effect_scale, 19.0 * effect_scale)
	dust.visible = not muzzle and quality_ratio > 0.75
	shockwave.visible = not muzzle
	shockwave.position = Vector3(0, ground - point.y + 0.2, 0)
	shockwave.scale = Vector3.ONE * 0.1
	flash.omni_range = radius * 2.5
	flash.visible = true
	for index in range(debris.size()):
		var piece: MeshInstance3D = debris[index]
		piece.visible = not muzzle and index < int(8 * quality_ratio)
		piece.position = Vector3.ZERO
		piece.scale = Vector3.ONE * effect_scale
		debris_velocity[index] = Vector3(rng.randf_range(-12, 12), rng.randf_range(9, 22), rng.randf_range(-12, 12)) * effect_scale

func _process(delta: float) -> void:
	if not active:
		return
	age += delta
	(fire.material_override as StandardMaterial3D).albedo_color.a = 0.9 * maxf(0.0, 1.0 - age / 0.85)
	(smoke.material_override as StandardMaterial3D).albedo_color.a = 0.42 * minf(age / 0.6, 1.0) * maxf(0.0, 1.0 - age / SMOKE_LIFE)
	(dust.material_override as StandardMaterial3D).albedo_color.a = 0.4 * maxf(0.0, 1.0 - age / DUST_LIFE)
	flash.light_energy = maxf(0.0, 18.0 * (1.0 - age / 0.28))
	flash.visible = age < 0.28
	if age < 0.65:
		var size: float = lerpf(0.2, radius * 1.8, age / 0.65)
		shockwave.scale = Vector3(size, 0.15, size)
		(shockwave.material_override as StandardMaterial3D).albedo_color.a = 0.32 * (1.0 - age / 0.65)
	for index in range(debris.size()):
		var piece: MeshInstance3D = debris[index]
		if not piece.visible:
			continue
		debris_velocity[index].y -= 9.81 * delta
		piece.position += debris_velocity[index] * delta
		piece.rotation += Vector3(2.1, 3.2, 1.4) * delta
		if global_position.y + piece.position.y < ground_y + 0.12:
			piece.position.y = ground_y - global_position.y + 0.12
			debris_velocity[index] = Vector3.ZERO
			piece.visible = false
	if age > EFFECT_LIFE:
		deactivate()

func deactivate() -> void:
	active = false
	visible = false
	set_process(false)
	for particles in [fire, smoke, dust]:
		particles.emitting = false
